//
//	SenseFramework/SFIdentificator.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFIdentificator.h"
#import "SFAudioSessionManager.h"

#define kSFIdentificationMeanSteps		10
#define kSFIdentificationStepsToSkip	 3


@interface SFIdentificator () <SFSignalProcessorDelegate> {
	
	int identificationStep;
	int stepsToSkip;
	BOOL identificationIsInProcess;
}

@property (nonatomic, assign) SFSensorID sensorID;
@property (nonatomic, assign) SFSensorIdentificationFingerprint fingerprint;

- (void)identificationDidComplete;
- (SFSensorType)convertSensorIDtoSensorType:(SFSensorID)sid;

@end




@implementation SFIdentificator

@synthesize deviceVolumeLimitThreshold;
@synthesize identificationThreshold;
@synthesize signalProcessor;
@synthesize fingerprint;
@synthesize delegate;
@synthesize sensorID;


#pragma mark -
#pragma mark Lifecycle


- (id)init {
	self = [super init];
	if (self) {
		
		// SIGNAL PROCESSOR
		
		self.signalProcessor = [[SFSignalProcessor alloc] init];
		self.signalProcessor.delegate = self;
		
		// default values
		identificationThreshold = SFSensorIdentificationThreshold;
		deviceVolumeLimitThreshold = SFDeviceVolumeLimitThreshold;
		
	}
	return self;
}


- (void)dealloc {
	
	self.signalProcessor = nil;
}


#pragma mark -
#pragma mark Identification


- (void)identificate {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) return;
	if (identificationIsInProcess) return;
	
	identificationIsInProcess = YES;
	
	NSLog(@"Start identification");
	
	stepsToSkip = kSFIdentificationStepsToSkip;
	identificationStep = 0;
	
	// set volume up to european default value
//	[[SFAudioSessionManager sharedManager] setHardwareOutputVolumeToRegionMaxValue];
	
	// setup signal processor
	self.signalProcessor.fftAnalyzer.meanSteps = kSFIdentificationMeanSteps;
	
	// set 00 amplitude
	self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitZero;
	self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitZero;
	
	[self.signalProcessor start];
}


- (void)abortIdentification {
	
	[self.signalProcessor stop];
	identificationIsInProcess = NO;
}


- (void)identificationDidComplete {
	
	[self.signalProcessor stop];
			
	if ([self.delegate respondsToSelector:@selector(identificatorDidObtainSensorIdentificationFingerprint:)])
		[self.delegate identificatorDidObtainSensorIdentificationFingerprint:fingerprint];
	
	SFSensorType sensorType = [self convertSensorIDtoSensorType:sensorID];
	NSLog(@"Identification complete: %@", [SFIdentificator sensorTypeToString:sensorType]);
	[self.delegate identificatorDidRecognizeSensor:sensorType];
	
	identificationIsInProcess = NO;
}


- (SFSensorType)convertSensorIDtoSensorType:(SFSensorID)sid {
	
	SFSensorType sensorType = SFSensorTypeUnknown;
	
	if ( sid.bit00 && !sid.bit01 && sid.bit10 && sid.bit11 )		// 1011 - Fields
		sensorType = SFSensorTypeFields;
	
	else if ( sid.bit00 && sid.bit01 && !sid.bit10 && !sid.bit11 )	// 1100 - Radiation
		sensorType = SFSensorTypeRadiation;
	
	else if ( sid.bit00 && !sid.bit01 && !sid.bit10 && sid.bit11 )	// 1001 - Humidity
		sensorType = SFSensorTypeHumidity;
	
	else if ( sid.bit00 && !sid.bit01 && sid.bit10 && !sid.bit11 )	// 1010 - Nitrates
		sensorType = SFSensorTypeNitrates;
	
	else NSLog(@"SIdentificator: warning, can't identify sid %d%d%d%d", sid.bit00, sid.bit01, sid.bit10, sid.bit11);
	
	return sensorType;
}


#pragma mark -
#pragma mark Signal Processor Delegate


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			
			// Use last measure amplitude instead of mean amplitude
			Float32 amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// skip some steps
			if (stepsToSkip > 0) {
				stepsToSkip--;
				if (stepsToSkip == 0) {
					
					// tell delegate microphone level
					if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceMicrophoneLevel:)])
						[self.delegate identificatorDidRecognizeDeviceMicrophoneLevel:amplitude];
					
					/*
					 
					// check device volume limit
					BOOL deviceVolumeIsLimited = (amplitude < deviceVolumeLimitThreshold);
					
					// update system preferences if user agreed
					BOOL canSetRegionAutomatically = [[NSUserDefaults standardUserDefaults] boolForKey:@"set_region_automatically_preference"];
					if (canSetRegionAutomatically) {
						[[NSUserDefaults standardUserDefaults] setBool:deviceVolumeIsLimited forKey:@"european_preference"];
					}
					
					// set volume back to logic max
					[[SFAudioSessionManager sharedManager] setHardwareOutputVolumeToRegionMaxValue];
					
					// tell delegate
					if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
						[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:deviceVolumeIsLimited];
					NSLog(@"deviceVolumeIsLimited: %@", deviceVolumeIsLimited?@"YES":@"NO");
					 
					 */
				}
				return;
			}
			
			BOOL bit = (amplitude >= identificationThreshold);
			
			switch (identificationStep) {
					
				// 00
				case 0: {
					NSLog(@"Measure 00 bit: %d", bit?1:0);
					sensorID.bit00 = bit;
					fingerprint.amplitude00 = amplitude;
					// 01 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitZero;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 01
				case 1: {
					NSLog(@"Measure 01 bit: %d", bit?1:0);
					sensorID.bit01 = bit;
					fingerprint.amplitude01 = amplitude;
					// 10 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitZero;
					break;
				}	
					
				// 10
				case 2: {
					NSLog(@"Measure 10 bit: %d", bit?1:0);
					sensorID.bit10 = bit;
					fingerprint.amplitude10 = amplitude;
					// 11 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 11
				case 3: {
					NSLog(@"Measure 11 bit: %d", bit?1:0);
					sensorID.bit11 = bit;
					fingerprint.amplitude11 = amplitude;
					// done
					[self identificationDidComplete];
					break;
				}
					
				default:
					break;
			}
			
			identificationStep ++;
			
		}
	});
}


/*
// amplitude debug log
 
- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			NSLog(@"left: %f right: %f amplitude: %f", self.signalProcessor.leftAmplitude, self.signalProcessor.rightAmplitude, amplitude);
		}
	});
}
*/


#pragma mark -
#pragma mark Utility


+ (NSString *)sensorTypeToString:(SFSensorType)sensorType {
	
	NSString *type;
	
	switch (sensorType) {
			
		case SFSensorTypeFields:
			type = @"EMF";
			break;
			
		case SFSensorTypeNitrates:
			type = @"Organic";
			break;
			
		case SFSensorTypeRadiation:
			type = @"Radiation";
			break;
			
		case SFSensorTypeHumidity:
			type = @"Humidity";
			break;
			
		case SFSensorTypeUnknown:
		default:
			type = @"Unknown";
			break;
	}
	
	return type;
}


@end
