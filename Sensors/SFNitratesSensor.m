//
//	SenseFramework/SFNitratesSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFNitratesSensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFNitratesSensorSafeDelayMeanSteps					200	// 4 sec
#define kSFNitratesSensorCalibrationMeanSteps				  3	// 0.06 sec (0.04 wait + 0.02 measure)
#define kSFNitratesSensorFirstTemperatureMeasureMeanSteps	200	// 4 sec
#define kSFNitratesSensorTemperatureMeasureMeanSteps		 10	// 0.2 sec
#define kSFNitratesSensorEmptyNitratesMeasureMeanSteps		 25	// 0.5 sec
#define kSFNitratesSensorNitratesMeasureMeanSteps			200	// 4.0 sec

#define kSFNitratesSensorSignalToNitratesCoef		395.37
#define kSFNitratesSensorCalibrationTime 5.0

#define kSFNitratesSensoriPhone4K1		 26.0
#define kSFNitratesSensoriPhone4K2		151.0
#define kSFNitratesSensoriPhone4K3		 93.0
#define kSFNitratesSensoriPhone4K4		0.000

#define kSFNitratesSensoriPhone5K1		 23.0
#define kSFNitratesSensoriPhone5K2		205.0
#define kSFNitratesSensoriPhone5K3		118.0
#define kSFNitratesSensoriPhone5K4		0.000

#define kSFNitratesSensoriPad4K1		 26.0
#define kSFNitratesSensoriPad4K2		164.0
#define kSFNitratesSensoriPad4K3		100.0
#define kSFNitratesSensoriPad4K4		0.000

#define kSFNitratesSensoriPadMiniK1		 23.0
#define kSFNitratesSensoriPadMiniK2		205.0
#define kSFNitratesSensoriPadMiniK3		118.0
#define kSFNitratesSensoriPadMiniK4		0.000

#define kSFNitratesSensoriPodTouch4K1	 26.0
#define kSFNitratesSensoriPodTouch4K2	154.0
#define kSFNitratesSensoriPodTouch4K3	 97.0
#define kSFNitratesSensoriPodTouch4K4	0.000

#define RANDOM_0_1() ((random() / (float)0x7fffffff))



@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@interface SFNitratesSensor ()
@property (nonatomic, strong) NSTimer *simulationTimer;
@end


@implementation SFNitratesSensor


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Nitrates sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		if (hardwarePlatform == SFDeviceHardwarePlatform_iPhone_5  ||
			hardwarePlatform == SFDeviceHardwarePlatform_iPhone_5C ||
			hardwarePlatform == SFDeviceHardwarePlatform_iPhone_5S) {
			self.K1 = kSFNitratesSensoriPhone5K1;
			self.K2 = kSFNitratesSensoriPhone5K2;
			self.K3 = kSFNitratesSensoriPhone5K3;
			self.K4 = kSFNitratesSensoriPhone5K4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPad_2 ||
				   hardwarePlatform == SFDeviceHardwarePlatform_iPad_3 ||
				   hardwarePlatform == SFDeviceHardwarePlatform_iPad_4) {
			self.K1 = kSFNitratesSensoriPad4K1;
			self.K2 = kSFNitratesSensoriPad4K2;
			self.K3 = kSFNitratesSensoriPad4K3;
			self.K4 = kSFNitratesSensoriPad4K4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPad_Mini ||
				   hardwarePlatform == SFDeviceHardwarePlatform_iPad_Mini_Retina ||
				   hardwarePlatform == SFDeviceHardwarePlatform_iPad_Air) {
			self.K1 = kSFNitratesSensoriPadMiniK1;
			self.K2 = kSFNitratesSensoriPadMiniK2;
			self.K3 = kSFNitratesSensoriPadMiniK3;
			self.K4 = kSFNitratesSensoriPadMiniK4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPod_Touch_4G ||
				   hardwarePlatform == SFDeviceHardwarePlatform_iPod_Touch_5G) {
			self.K1 = kSFNitratesSensoriPodTouch4K1;
			self.K2 = kSFNitratesSensoriPodTouch4K2;
			self.K3 = kSFNitratesSensoriPodTouch4K3;
			self.K4 = kSFNitratesSensoriPodTouch4K4;
		} else {
			self.K1 = kSFNitratesSensoriPhone4K1;
			self.K2 = kSFNitratesSensoriPhone4K2;
			self.K3 = kSFNitratesSensoriPhone4K3;
			self.K4 = kSFNitratesSensoriPhone4K4;
		}
		
	}
	return self;
}


- (void)dealloc {
	[self.simulationTimer invalidate];
	self.simulationTimer = nil;
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
	
	_state = SFNitratesSensorStateFirstTemperatureMeasurement;
	
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


- (void)setupForEmptyNitratesMeasurement {
	
	_state = SFNitratesSensorStateEmptyNitratesMeasurement;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorEmptyNitratesMeasureMeanSteps;
}


- (void)setupForNitratesMeasurement {
	
	_state = SFNitratesSensorStateNitratesMeasurement;
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFNitratesSensorNitratesMeasureMeanSteps;
}


#pragma mark -
#pragma mark Calibration


- (void)startCalibration {
	
	if (![self isPluggedIn]) {
		
		BOOL iamSimulated = [[SFSensorManager sharedManager] isSensorSimulated];
		if (iamSimulated) {
			
			self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:self.calibrationTime target:self selector:@selector(simulateCalibrationComplete) userInfo:nil repeats:NO];
			[super startCalibration];
			return;
		}
		
		NSLog(@"SFNitratesSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	[self reset];
	[self setOutputVolumeUp];
	[self setupForSafeDelay];
	[self.signalProcessor start];
	
	[super startCalibration];
}


- (void)calibrationComplete {
	
	_state = SFNitratesSensorStateCalibrationComplete;
	[super calibrationComplete];
}


- (NSTimeInterval)calibrationTime {
	return kSFNitratesSensorCalibrationTime;
}


#pragma mark -
#pragma mark Measure


- (void)startMeasure {
	
	[super startMeasure];
	
	if (_state != SFNitratesSensorStateCalibrationComplete) return;
	
	BOOL iamSimulated = [[SFSensorManager sharedManager] isSensorSimulated];
	if (iamSimulated) {
		self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(simulateMeasurementComplete) userInfo:nil repeats:NO];
		return;
	}
	
	[self setupForNitratesMeasurement];
	[self.signalProcessor start];
}


- (void)stopMeasure {
	
	[self.simulationTimer invalidate];
	self.simulationTimer = nil;
	
	[self.signalProcessor stop];
	_state = SFNitratesSensorStateCalibrationComplete;
	
	[super stopMeasure];
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
	
	return T;
}


- (float)calculateNitratesWithNitratesLevel:(float)nitratesLevel {
	
	// coefficients
	float K1 = _K1;
	float K4 = _K4;
	
	// measurements
	float U2 = _calibration_level;
	float U3 = nitratesLevel;
	
	// temperature
	float T = _temperature;
	
	// nitrates
	float N = (1 - 0.01 * (T - 20)) * K1 * (U2 - U3 - K4) / U3;
	
	// x4 as convertion to ppm NO3
	N = N * 4.0;
	
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
			
		case SFNitratesSensorStateCalibration: {
			_calibration_level = amplitude;
			[self setupForFirstTemperatureMeasurement];
			break;
		}
			
		case SFNitratesSensorStateFirstTemperatureMeasurement: {
			_temperature_level = amplitude;
			_temperature = [self calculateTemperature];
			[self setupForEmptyNitratesMeasurement];
			break;
		}
			
		case SFNitratesSensorStateEmptyNitratesMeasurement: {
			_empty_nitrates_level = amplitude;
			_empty_nitrates = [self calculateNitratesWithNitratesLevel:_empty_nitrates_level];
			NSLog(@"_empty_nitrates %g", _empty_nitrates);
			[self calibrationComplete];
			break;
		}
			
		case SFNitratesSensorStateNitratesMeasurement: {
			_nitrates_level = amplitude;
			_nitrates = [self calculateNitratesWithNitratesLevel:_nitrates_level];
			NSLog(@"_nitrates %g", _nitrates);
			_nitrates = MAX(_nitrates - _empty_nitrates, 0);
			NSLog(@"zeroed _nitrates %g", _nitrates);

			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@(_nitrates)];
			});
			[self stopMeasure];
			break;
		}
			
		case SFNitratesSensorStateTemperatureMeasurement: {
			_temperature_level = amplitude;
			_temperature = [self calculateTemperature];
			[self setupForNitratesMeasurement];
			break;
		}
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark Utilities


- (void)reset {
	
	_temperature_level = 0;
	_calibration_level = 0;
	_empty_nitrates_level = 0;
	_nitrates_level = 0;
	_empty_nitrates = 0;
	_temperature = 0;
	_nitrates = 0;
}


- (void)setOutputVolumeUp {
	
	float outputVolume;
	id nitrat_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"nitrat_volume"];
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (nitrat_volume) {
		outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"nitrat_volume"];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	} else if (european_preference) {
		outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	}
}


#pragma mark -
#pragma mark Simulation


- (void)simulateCalibrationComplete {
	
	_empty_nitrates = 2.0 * RANDOM_0_1();
	NSLog(@"_empty_nitrates %g", _empty_nitrates);
	[self calibrationComplete];
}


- (void)simulateMeasurementComplete {
	
	_nitrates = 60.0 * RANDOM_0_1();
	_nitrates = MAX(_nitrates - _empty_nitrates, 0);
	NSLog(@"_nitrates %g", _nitrates);
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@(_nitrates)];
	});
	[self stopMeasure];
}


@end
