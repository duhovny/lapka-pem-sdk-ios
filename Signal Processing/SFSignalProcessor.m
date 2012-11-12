//
//  SenseFramework/SFSignalProcessor.m
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFSignalProcessor.h"

#define kDefaultSampleRate 44100
#define kDefaultFrequency 18000
#define kDefaultAmplitude 1.0

OSStatus RenderAudio(
					void *inRefCon, 
					AudioUnitRenderActionFlags 	*ioActionFlags, 
					const AudioTimeStamp 		*inTimeStamp, 
					UInt32 						inBusNumber, 
					UInt32 						inNumberFrames, 
					AudioBufferList 			*ioData);


OSStatus RenderAudio(
					void *inRefCon, 
					AudioUnitRenderActionFlags 	*ioActionFlags, 
					const AudioTimeStamp 		*inTimeStamp, 
					UInt32 						inBusNumber, 
					UInt32 						inNumberFrames, 
					AudioBufferList 			*ioData)

{
	// Get signal processor
	SFSignalProcessor *signalProcessor = (__bridge SFSignalProcessor *)inRefCon;
	
	// Render Input
	OSStatus err = AudioUnitRender(signalProcessor->audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	if (err) { printf("RenderAudio: error %d\n", (int)err); return err; }
	
	
	// -----------------------------------------------
	// IMPULSE DETECTION
	
	if (signalProcessor.impulseDetectorEnabled) {
		Float32 *tmp_samples = (Float32*)(ioData->mBuffers[0].mData);
		[signalProcessor.impulseDetector processImpulseDetectionWithData:tmp_samples];
	}
	
	
	// -----------------------------------------------
	// FFT
	
	if (signalProcessor.fftAnalyzerEnabled) {
		Float32 *samples = (Float32*)(ioData->mBuffers[0].mData);
		[signalProcessor.fftAnalyzer processFFTWithData:samples];
	}
	
	
	// -----------------------------------------------
	// RENDER TONE
	
	// Get the tone parameters out of the view controller
	double left_theta = signalProcessor->left_theta;
	double right_theta = signalProcessor->right_theta;
	double left_theta_increment = 2.0 * M_PI * signalProcessor.leftFrequency / signalProcessor.sampleRate;
	double right_theta_increment = 2.0 * M_PI * signalProcessor.rightFrequency / signalProcessor.sampleRate;
	
	// This is a stereo tone generator so we need the both buffers
	const int channel_left = 0;
	const int channel_right = 1;
	Float32 *buffer_left = (Float32 *)ioData->mBuffers[channel_left].mData;
	Float32 *buffer_right = (Float32 *)ioData->mBuffers[channel_right].mData;
	
	// Variables for generation cycle 
	float leftWaveValue;
	float rightWaveValue;
	float leftPhaseSign;
	float rightPhaseSign;
	
	// Generate the samples
	for (UInt32 frame = 0; frame < inNumberFrames; frame++) 
	{	
		// 1. Check scheduled amplitude
		if (signalProcessor.scheduledLeftAmplitudeUpdate) {
			if (signalProcessor.scheduledLeftAmplitudeDelay == 0) {
				// update
				signalProcessor.leftAmplitude = signalProcessor.scheduledLeftAmplitudeValue;
				signalProcessor.scheduledLeftAmplitudeUpdate = NO;
			} else {
				signalProcessor.scheduledLeftAmplitudeDelay--;
			}
		}
		if (signalProcessor.scheduledRightAmplitudeUpdate) {
			if (signalProcessor.scheduledRightAmplitudeDelay == 0) {
				// update
				signalProcessor.rightAmplitude = signalProcessor.scheduledRightAmplitudeValue;
				signalProcessor.scheduledRightAmplitudeUpdate = NO;
			} else {
				signalProcessor.scheduledRightAmplitudeDelay--;
			}
		}
		
		// 2. wave value
		leftWaveValue  = (signalProcessor.leftWaveType  == SFSignalWaveTypeSquare) ? ((sin(left_theta)  > 0) ? 1.0 : -1.0) : sin(left_theta);
		rightWaveValue = (signalProcessor.rightWaveType == SFSignalWaveTypeSquare) ? ((sin(right_theta) > 0) ? 1.0 : -1.0) : sin(right_theta);
		
		// 3. phase sign
		leftPhaseSign = signalProcessor.antiphase ? -1.0 : 1.0;
		rightPhaseSign = 1.0;
		
		// 4. signal
		buffer_left[frame] = leftPhaseSign * leftWaveValue * signalProcessor.leftAmplitude;
		buffer_right[frame] = rightPhaseSign * rightWaveValue * signalProcessor.rightAmplitude;
		
		// 5. theta step
		left_theta += left_theta_increment;
		right_theta += right_theta_increment;
		
		if (left_theta > 2.0 * M_PI)
			left_theta -= 2.0 * M_PI;
		
		if (right_theta > 2.0 * M_PI)
			right_theta -= 2.0 * M_PI;
	}
	
	// Store the theta back in the view controller
	signalProcessor->left_theta = left_theta;
	signalProcessor->right_theta = right_theta;
	
	return noErr;
}


@interface SFSignalProcessor (private)
- (void)createAudioUnit;
- (void)removeAudioUnit;

// Utility
- (int)convertSecondsToRenderSteps:(NSTimeInterval)seconds;
@end


@implementation SFSignalProcessor

@synthesize antiphase;
@synthesize numberOfFrames;
@synthesize fftAnalyzer;
@synthesize impulseDetector;
@synthesize fftAnalyzerEnabled;
@synthesize impulseDetectorEnabled;
@synthesize leftFrequency;
@synthesize rightFrequency;
@synthesize sampleRate;
@synthesize leftAmplitude;
@synthesize rightAmplitude;
@synthesize leftWaveType;
@synthesize rightWaveType;
@synthesize delegate;

@synthesize scheduledLeftAmplitudeDelay;
@synthesize scheduledLeftAmplitudeUpdate;
@synthesize scheduledLeftAmplitudeValue;

@synthesize scheduledRightAmplitudeDelay;
@synthesize scheduledRightAmplitudeUpdate;
@synthesize scheduledRightAmplitudeValue;



#pragma mark -
#pragma mark Lifecycle


- (id)init {
	if ((self = [super init])) {
		
		// default values
		self.amplitude = kDefaultAmplitude;
		self.sampleRate = kDefaultSampleRate;
		self.waveType = SFSignalWaveTypeSin;
		self.antiphase = YES;
		
		[self createAudioUnit];
		
		
		// SETUP FFT
		
		// Get unit's max frames per slice
		UInt32 maxFPS;
		UInt32 size = sizeof(maxFPS);
		OSErr err = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size);
		NSAssert1(err == noErr, @"Error getting maximum frames per slice: %hd", err);
		
		// Number of frames
		// refactor: Where did you get 4?
		numberOfFrames = maxFPS/4;
		
		// setup FFT
		self.fftAnalyzer = [[SFSignalFFTAnalyzer alloc] initWithNumberOfFrames:numberOfFrames];
		self.fftAnalyzer.sampleRate = sampleRate;
		self.fftAnalyzer.meanSteps = 100;
		self.fftAnalyzer.delegate = self;
		
		// setup SID
		self.impulseDetector = [[SFSignalImpulseDetector alloc] initWithNumberOfFrames:numberOfFrames];
		self.impulseDetector.delegate = self;
		
		// enable FFT, disable Impulse by default
		self.fftAnalyzerEnabled = YES;
		self.impulseDetectorEnabled = NO;
		
		// default frequency (it's last because optimizeFrequency depends on sampleRate and numberOfFrames)
		self.frequency = [self optimizeFrequency:kDefaultFrequency];
	}
	return self;
}


- (void)dealloc {
	
	self.fftAnalyzer = nil;
	self.impulseDetector = nil;
	[self removeAudioUnit];
}


#pragma mark -
#pragma mark Audio Unit


- (void)createAudioUnit {
	
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &audioUnit);
	NSAssert1(audioUnit, @"Error creating unit: %hd", err);
	
	// Enable input
	UInt32 one = 1;
	err = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
	NSAssert1(err == noErr, @"couldn't enable input on the remote I/O unit", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderAudio;
	input.inputProcRefCon = (__bridge void *)self;
	err = AudioUnitSetProperty(audioUnit, 
							   kAudioUnitProperty_SetRenderCallback, 
							   kAudioUnitScope_Input,
							   0, 
							   &input, 
							   sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %hd", err);
	
	
	// Set the format to 32 bit, two channels, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;	
	streamFormat.mBytesPerFrame = four_bytes_per_float;		
	streamFormat.mChannelsPerFrame = 2;
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (audioUnit,
								kAudioUnitProperty_StreamFormat,
								kAudioUnitScope_Input,
								0,
								&streamFormat,
								sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting output stream format: %hd", err);
	err = AudioUnitSetProperty (audioUnit,
								kAudioUnitProperty_StreamFormat,
								kAudioUnitScope_Output,
								1,
								&streamFormat,
								sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting input stream format: %hd", err);
	
	// Initialize
	err = AudioUnitInitialize(audioUnit);
	NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
}


- (void)removeAudioUnit {
	
	AudioUnitUninitialize(audioUnit);
	AudioComponentInstanceDispose(audioUnit);
	audioUnit = nil;
}


- (void)start {
	
	NSLog(@"SSignalProcessor: start");
	
	OSErr err = AudioOutputUnitStart(audioUnit);
	NSAssert1(err == noErr, @"Error start unit: %hd", err);
}


- (void)stop {
	
	NSLog(@"SSignalProcessor: stop");
	
	OSErr err = AudioOutputUnitStop(audioUnit);
	NSAssert1(err == noErr, @"Error stop unit: %hd", err);
}


#pragma mark -
#pragma mark SSignalFFTAnalyzerDelegate


- (void)fftAnalyzerDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	if ([delegate respondsToSelector:@selector(signalProcessorDidUpdateMeanAmplitude:)])
		[delegate signalProcessorDidUpdateMeanAmplitude:meanAmplitude];
}


- (void)fftAnalyzerDidUpdateAmplitude:(Float32)amplitude {
	
	if ([delegate respondsToSelector:@selector(signalProcessorDidUpdateAmplitude:)])
		[delegate signalProcessorDidUpdateAmplitude:amplitude];
}


#pragma mark -
#pragma mark SSignalImpulseDetectorDelegate


- (void)impulseDetectorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	if ([delegate respondsToSelector:@selector(signalProcessorDidUpdateMeanAmplitude:)])
		[delegate signalProcessorDidUpdateMeanAmplitude:meanAmplitude];
}


- (void)impulseDetectorDidUpdateMaxAmplitude:(Float32)maxAmplitude {
	
	if ([delegate respondsToSelector:@selector(signalProcessorDidUpdateMaxAmplitude:)])
		[delegate signalProcessorDidUpdateMaxAmplitude:maxAmplitude];
}


- (void)impulseDetectorDidDetectImpulse {
	
	if ([delegate respondsToSelector:@selector(signalProcessorDidRecognizeImpulse)])
		[delegate signalProcessorDidRecognizeImpulse];
}


#pragma mark -
#pragma mark Setters


- (void)setFrequency:(double)value {
	
	self.leftFrequency = value;
	self.rightFrequency = value;
	self.analyzerFrequency = value;
}


- (double)analyzerFrequency {
	
	if (!fftAnalyzer) return 0.0;
	return fftAnalyzer.frequency;
}


- (void)setAnalyzerFrequency:(double)value {
	
	if (!fftAnalyzer) return;
	fftAnalyzer.frequency = value;
}


- (void)setAmplitude:(double)value {
	
	self.leftAmplitude = value;
	self.rightAmplitude = value;
}


- (void)setWaveType:(SFSignalWaveType)value {
	
	self.leftWaveType = value;
	self.rightWaveType = value;
}


- (void)setLeftAmplitude:(double)value afterDelay:(NSTimeInterval)delay {
	
	self.scheduledLeftAmplitudeDelay = [self convertSecondsToRenderSteps:delay];
	self.scheduledLeftAmplitudeValue = value;
	self.scheduledLeftAmplitudeUpdate = YES;
	
	printf("setLeftAmplitude afterDelay: %f, in steps: %d\n", delay, self.scheduledLeftAmplitudeDelay);
}


- (void)setRightAmplitude:(double)value afterDelay:(NSTimeInterval)delay {
	
	self.scheduledRightAmplitudeDelay = [self convertSecondsToRenderSteps:delay];
	self.scheduledRightAmplitudeValue = value;
	self.scheduledRightAmplitudeUpdate = YES;
}


- (void)setSampleRate:(double)value {
	
	if (sampleRate == value) return;
	sampleRate = value;
	
	if (!fftAnalyzer) return;
	fftAnalyzer.sampleRate = sampleRate;
}


#pragma mark -
#pragma mark Utilities


- (double)optimizeFrequency:(double)frequency {
	
	int frequency_bin = frequency * self.numberOfFrames / self.sampleRate;
	double optimizedFrequency = frequency_bin * self.sampleRate / self.numberOfFrames;
	
//	optimizedFrequency = round(optimizedFrequency);
	
	NSLog(@"optimizeFrequency:");
	NSLog(@"numberOfFrames: %ld", self.numberOfFrames);
	NSLog(@"sampleRate: %f", self.sampleRate);
	NSLog(@"frequency: %f", frequency);
	NSLog(@"frequency_bin: %d", frequency_bin);
	NSLog(@"optimizedFrequency: %f", optimizedFrequency);
	
	return optimizedFrequency;
}


- (int)convertSecondsToRenderSteps:(NSTimeInterval)seconds {
	
	// let's take 1024 steps as 10 ms long
	// so 1 second will be equal to 1024 * 100 = 102400 steps
	
	return seconds * 102400;
}


@end
