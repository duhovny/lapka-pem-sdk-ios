//
//	SenseFramework/SFNitratesSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFNitratesSensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"

#define kSFNitratesSensorSafeDelayMeanSteps					200	// 4 sec
#define kSFNitratesSensorCalibrationMeanSteps				  3	// 0.06 sec (0.04 wait + 0.02 measure)
#define kSFNitratesSensorFirstTemperatureMeasureMeanSteps	200	// 4 sec
#define kSFNitratesSensorTemperatureMeasureMeanSteps		 10	// 0.2 sec
#define kSFNitratesSensorNitratesMeasureMeanSteps			 10	// 0.2 sec

#define kSFNitratesSensorSignalToNitratesCoef		395.37

#define kSFNitratesSensorDefaultK1 306.0
#define kSFNitratesSensorDefaultK2 209.0
#define kSFNitratesSensorDefaultK3 111.0
#define kSFNitratesSensorDefaultK4 0.071




@implementation SFNitratesSensor

@synthesize pluggedIn;
@dynamic delegate;
@synthesize isOn;


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Nitrates sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		self.K1 = kSFNitratesSensorDefaultK1;
		self.K2 = kSFNitratesSensorDefaultK2;
		self.K3 = kSFNitratesSensorDefaultK3;
		self.K4 = kSFNitratesSensorDefaultK4;
		
	}
	return self;
}


#pragma mark -
#pragma mark Setup


- (void)setupForSafeDelay {

	_state = SFNitratesSensorStateSafeDelay;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorSafeDelayMeanSteps;
}


- (void)setupForCalibration {
	
	_state = SFNitratesSensorStateCalibration;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorCalibrationMeanSteps;
}


- (void)setupForFirstTemperatureMeasurement {
	
	_state = SFNitratesSensorStateTemperatureMeasurement;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorFirstTemperatureMeasureMeanSteps;
}


- (void)setupForTemperatureMeasurement {
	
	_state = SFNitratesSensorStateTemperatureMeasurement;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorTemperatureMeasureMeanSteps;
}


- (void)setupForNitratesMeasurement {
	
	_state = SFNitratesSensorStateNitratesMeasurement;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorNitratesMeasureMeanSteps;
}


#pragma mark -
#pragma mark ON/OFF


- (void)switchOn {
	
	if (![self isPluggedIn]) {
		NSLog(@"SFNitratesSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	if ([self isOn]) {
		NSLog(@"SFNitratesSensor is already on.");
		return;
	}
	
	_temperature_level = 0;
	_calibration_level = 0;
	_nitrates_level = 0;
	
	_temperature = 0;
	_nitrates = 0;
	
	// set volume up
	float outputVolume;
	id nitrat_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"nitrat_volume"];
	if (nitrat_volume) outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"nitrat_volume"];
	else outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
	[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	
	[self setupForSafeDelay];
	[self.signalProcessor start];
	
	isOn = YES;
	[super switchOn];
	
	NSLog(@"SFNitratesSensor switched on");
}


- (void)switchOff {
	
	[self.signalProcessor stop];
	_state = SFNitratesSensorStateOff;
	
	isOn = NO;
	[super switchOff];
	
	NSLog(@"SFNitratesSensor switched off");
}


- (void)restart {
	
	if (![self isPluggedIn]) return;
	if (![self isOn]) return;
	
	[self switchOff];
	[self switchOn];
}


#pragma mark -
#pragma mark Calculation


- (float)calculateTemperature {
	
	// coefficients
	float K2 = _K2;
	float K3 = _K3;
	
	// measurements
	float U1 = _temperature_level;
	float U2 = _calibration_level;
	
	// temperature
	float T = K3 - K2 * U1 / U2;
	
	
//	NSLog(@"-------------------");
//	NSLog(@"calibration level: %f", _calibration_level);
//	NSLog(@"temperature level: %f", _temperature_level);
//	NSLog(@"temperature: %f", T);
//	NSLog(@"-------------------");
	
	return T;
}


- (float)calculateNitrates {
	
	// coefficients
	float K1 = _K1;
	float K4 = _K4;
	
	// measurements
	float U2 = _calibration_level;
	float U3 = _nitrates_level;
	
	// temperature
	float T = _temperature;
	
	// nitrates
	float N = (1 - 0.01 * (20 - T)) * K1 * (U2 - U3 - K4) / U3;
	
	// limit to (0..5000)
//	N = MAX(N, 0);
//	N = MIN(N, 5000);
	
	return N;
}


#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {

	float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
	
	switch (_state) {
			
		case SFNitratesSensorStateOff:
			NSLog(@"Warning: nitratesSensor get measure result when off.");
			break;
			
		case SFNitratesSensorStateSafeDelay:
			[self setupForCalibration];
			break;
			
		case SFNitratesSensorStateCalibration:
			_calibration_level = amplitude;
			[self setupForFirstTemperatureMeasurement];
			break;
			
		case SFNitratesSensorStateTemperatureMeasurement:
			_temperature_level = amplitude;
			_temperature = [self calculateTemperature];
			[self setupForNitratesMeasurement];
			break;
			
		case SFNitratesSensorStateNitratesMeasurement:
			_nitrates_level = amplitude;
			_nitrates = [self calculateNitrates];
			[self.delegate nitratesSensorGotNitrates:_nitrates];
			[self setupForTemperatureMeasurement];
			break;
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}


@end
