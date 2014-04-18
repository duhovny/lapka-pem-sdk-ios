//
//	SenseFramework/SFFieldSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFFieldSensor.h"
#import "SFAudioSessionManager.h"
#import "SFSignalProcessor.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFFieldSensorFrequency 16000
#define kSFFieldSensorMeanSteps 25


#define kSFFieldSensorScaleCoef_Default		1.0
#define kSFFieldSensorScaleCoef_iPhone4		1.0
#define kSFFieldSensorScaleCoef_iPhone4S	0.8
#define kSFFieldSensorScaleCoef_iPhone5		2.5
#define kSFFieldSensorScaleCoef_iPad4		0.8
#define kSFFieldSensorScaleCoef_iPadMini	0.8
#define kSFFieldSensorScaleCoef_iPod4		1.6


#define kSFFieldSensorHF_K1 30.0
#define kSFFieldSensorHF_K2  4.5

#define kSFFieldSensorLF_K1  10.0
#define kSFFieldSensorLF_K2 320.0

#define kSF_PositiveLFFieldThreshold 0.0100


@interface SFFieldSensor () {
	int _stepsToSkip;
	BOOL _fftNoizeVectorCorrectionEnabled;
}

@end


@implementation SFFieldSensor

@synthesize pluggedIn;
@synthesize lowFrequencyField;
@synthesize highFrequencyField;
@synthesize meanLowFrequencyField;
@synthesize meanHighFrequencyField;
@synthesize measureLowFrequencyField;
@synthesize measureHighFrequencyField;
@synthesize state;
@synthesize isOn;
@dynamic delegate;




#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		// default values
		self.measureLowFrequencyField = NO;
		self.measureHighFrequencyField = YES;
		
		_stepsToSkip = 0;
		
		self.hf_K1 = kSFFieldSensorHF_K1;
		self.hf_K2 = kSFFieldSensorHF_K2;
		self.lf_K1 = kSFFieldSensorLF_K1;
		self.lf_K2 = kSFFieldSensorLF_K2;
		
		
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		
		switch (hardwarePlatform) {
				
			case SFDeviceHardwarePlatform_iPhone_3GS:
			case SFDeviceHardwarePlatform_iPhone_4:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPhone4;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPhone_4S:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPhone4S;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPhone_5:
			case SFDeviceHardwarePlatform_iPod_Touch_5G:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPhone5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPod_Touch_4G:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPod4;
				break;
			}
			
			case SFDeviceHardwarePlatform_iPad_2:
			case SFDeviceHardwarePlatform_iPad_3:
			case SFDeviceHardwarePlatform_iPad_4:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPad4;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPad_Mini:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_iPadMini;
				break;
			}
				
			default:
			{
				self.scaleCoef = kSFFieldSensorScaleCoef_Default;
				break;
			}
		}
		
	}
	return self;
}




#pragma mark -
#pragma mark ON/OFF


- (void)switchOn {
	
	if (![self isPluggedIn]) {
		NSLog(@"SFieldSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	if ([self isOn]) {
		NSLog(@"SFieldSensor is already on.");
		return;
	}
	
	// set volume up
	float outputVolume;
	id field_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"field_volume"];
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (field_volume) {
		NSLog(@"SFFieldSensor: set specific field volume");
		outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"field_volume"];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	} else if (european_preference) {
		NSLog(@"SFFieldSensor: set current region volume");
		outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	}
	
	// setup signal processor according to state
	self.signalProcessor.frequency = [self.signalProcessor optimizeFrequency:kSFFieldSensorFrequency];
	self.signalProcessor.fftAnalyzer.meanSteps = kSFFieldSensorMeanSteps;
	if (measureLowFrequencyField) {
		NSLog(@"SFieldSensor: low frequency");
		[self setupSignalProcessorForLowFrequencyMeasure];
		state = kSFFieldSensorStateLowFrequencyMeasurement;
	} else if (measureHighFrequencyField) {
		NSLog(@"SFieldSensor: high frequency");
		_stepsToSkip = 1;
		[self setupSignalProcessorForHighFrequencyMeasure];
		state = kSFFieldSensorStateHighFrequencyMeasurement;
	}
	
	[self.signalProcessor start];
	isOn = YES;
	
	[super switchOn];
}


- (void)switchOff {
	
	[self.signalProcessor stop];
	
	state = kSFFieldSensorStateOff;
	isOn = NO;
	lowFrequencyField = 0;
	highFrequencyField = 0;
	
	[super switchOff];
}




#pragma mark -
#pragma mark Signal Processor setup


- (void)setupSignalProcessorForLowFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
}


- (void)setupSignalProcessorForHighFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
}


#pragma mark -
#pragma mark FFT Noize Vector Correction


- (void)enableFFTNoizeVectorCorrection {
	
	_fftNoizeVectorCorrectionEnabled = YES;
	self.signalProcessor.fftAnalyzer.useNoizeVectorCorrection = YES;
}


- (void)disableFFTNoizeVectorCorrection {
	
	_fftNoizeVectorCorrectionEnabled = NO;
	self.signalProcessor.fftAnalyzer.useNoizeVectorCorrection = NO;
}


- (void)resetFFTNoizeVectorCorrection {
	
	self.signalProcessor.fftAnalyzer.realSignalMax = 0;
	self.signalProcessor.fftAnalyzer.imagSignalMax = 0;
	self.signalProcessor.fftAnalyzer.realNoize = 0;
	self.signalProcessor.fftAnalyzer.imagNoize = 0;
	self.signalProcessor.fftAnalyzer.realZero = 0;
	self.signalProcessor.fftAnalyzer.imagZero = 0;
}




#pragma mark -
#pragma mark Calculations


- (float)calculateLowFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude * _scaleCoef;
	
	float K1 = _lf_K1;
	float K2 = _lf_K2;
	
	float U = (exp(K1 * value) - 1) * K2;
	
	return MAX(U, 0);
}


- (float)calculateHighFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude * _scaleCoef;
	
	float K1 = _hf_K1;
	float K2 = _hf_K2;
	
	float U = (exp(K1 * value) - 1) * K2;
	
	return MAX(U, 0);
}




#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	
	if (_stepsToSkip > 0) return;
	
	switch (state) {
			
		case kSFFieldSensorStateOff:
			break;
			
		case kSFFieldSensorStateLowFrequencyMeasurement:
		{
			lowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateLowFrequencyField:lowFrequencyField];
			break;
		}
			
		case kSFFieldSensorStateHighFrequencyMeasurement:
		{
			highFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateHighFrequencyField:highFrequencyField];
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
		
	if (_stepsToSkip > 0) {
		_stepsToSkip--;
		return;
	}
		
	switch (state) {
			
		case kSFFieldSensorStateOff:
			NSLog(@"Warning: SFieldSensor get measure result when off.");
			break;
			
		case kSFFieldSensorStateLowFrequencyMeasurement:
		{
			meanLowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:meanAmplitude];
			[self.delegate fieldSensorDidUpdateMeanLowFrequencyField:meanLowFrequencyField];
			break;
		}
			
		case kSFFieldSensorStateHighFrequencyMeasurement:
		{
			meanHighFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:meanAmplitude];
			[self.delegate fieldSensorDidUpdateMeanHighFrequencyField:meanHighFrequencyField];
			break;
		}
			
		default:
			break;
	}
}




#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	// refactor: this is not taking sensor type in account
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}




#pragma mark -
#pragma mark Setters


- (void)setMeasureLowFrequencyField:(BOOL)value {
	
	measureLowFrequencyField = value;
	
	// switch high ON if you switching low OFF
	if (!measureLowFrequencyField && !measureHighFrequencyField)
		measureHighFrequencyField = YES;
}


- (void)setMeasureHighFrequencyField:(BOOL)value {
	
	measureHighFrequencyField = value;
	
	// switch low ON if you switching high OFF
	if (!measureHighFrequencyField && !measureLowFrequencyField)
		measureLowFrequencyField = YES;
}




@end
