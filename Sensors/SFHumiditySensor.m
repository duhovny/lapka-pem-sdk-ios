//
//	SenseFramework/SFHumiditySensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFHumiditySensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFHumiditySensorResettingMeanSteps			250	// 5 sec
#define kSFHumiditySensorCalibratingMeanSteps		 10	// 0.2 sec
#define kSFHumiditySensorSecondResettingMeanSteps	 25	// 0.5 sec
#define kSFHumiditySensorFirstTemperatureMeanSteps  200	// 4 sec
#define kSFHumiditySensorTemperatureMeanSteps		 50	// 1.0 sec
#define kSFHumiditySensorHumidityMeanSteps			 50	// 1.0 sec

int const SFHumiditySensorCalibrationDuration = (kSFHumiditySensorResettingMeanSteps +
												 kSFHumiditySensorCalibratingMeanSteps +
												 kSFHumiditySensorSecondResettingMeanSteps +
												 kSFHumiditySensorFirstTemperatureMeanSteps) / 42;

#define kSFHumiditySensoriPhone3GSK1	122.0
#define kSFHumiditySensoriPhone3GSK2	 77.4
#define kSFHumiditySensoriPhone3GSK3	0.314
#define kSFHumiditySensoriPhone3GSK4	0.982
#define kSFHumiditySensoriPhone3GSK5	 1.26

#define kSFHumiditySensoriPhone4K1		122.0
#define kSFHumiditySensoriPhone4K2		 77.4
#define kSFHumiditySensoriPhone4K3		0.261
#define kSFHumiditySensoriPhone4K4		0.982
#define kSFHumiditySensoriPhone4K5	 	 1.26

#define kSFHumiditySensoriPhone4SK1		122.0
#define kSFHumiditySensoriPhone4SK2	 	 77.4
#define kSFHumiditySensoriPhone4SK3		0.314
#define kSFHumiditySensoriPhone4SK4		0.982
#define kSFHumiditySensoriPhone4SK5	 	 1.26

#define kSFHumiditySensoriPhone5K1		122.0
#define kSFHumiditySensoriPhone5K2		 77.4
#define kSFHumiditySensoriPhone5K3		0.261
#define kSFHumiditySensoriPhone5K4		1.056
#define kSFHumiditySensoriPhone5K5		 1.26

#define kSFHumiditySensoriPad2K1		109.9
#define kSFHumiditySensoriPad2K2		 66.5
#define kSFHumiditySensoriPad2K3		0.286
#define kSFHumiditySensoriPad2K4		1.010
#define kSFHumiditySensoriPad2K5		 1.33

#define kSFHumiditySensoriPad3K1		126.6
#define kSFHumiditySensoriPad3K2		 83.1
#define kSFHumiditySensoriPad3K3		0.314
#define kSFHumiditySensoriPad3K4		0.990
#define kSFHumiditySensoriPad3K5		 1.32

#define kSFHumiditySensoriPad4K1		129.9
#define kSFHumiditySensoriPad4K2		 85.6
#define kSFHumiditySensoriPad4K3		0.318
#define kSFHumiditySensoriPad4K4		0.986
#define kSFHumiditySensoriPad4K5		 1.30

#define kSFHumiditySensoriPadMiniK1		126.6
#define kSFHumiditySensoriPadMiniK2		 83.1
#define kSFHumiditySensoriPadMiniK3		0.314
#define kSFHumiditySensoriPadMiniK4		0.990
#define kSFHumiditySensoriPadMiniK5		 1.32

#define kSFHumiditySensoriPod4K1		119.0
#define kSFHumiditySensoriPod4K2		 75.6
#define kSFHumiditySensoriPod4K3		0.311
#define kSFHumiditySensoriPod4K4		0.994
#define kSFHumiditySensoriPod4K5		 1.32

#define RANDOM_0_1() ((random() / (float)0x7fffffff))


@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@interface SFHumiditySensor ()
@property (nonatomic, strong) NSTimer *simulationTimer;
@end


@implementation SFHumiditySensor


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Humidity sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		
		switch (hardwarePlatform) {
				
			case SFDeviceHardwarePlatform_iPhone_3GS:
			{
				self.K1 = kSFHumiditySensoriPhone3GSK1;
				self.K2 = kSFHumiditySensoriPhone3GSK2;
				self.K3 = kSFHumiditySensoriPhone3GSK3;
				self.K4 = kSFHumiditySensoriPhone3GSK4;
				self.K5 = kSFHumiditySensoriPhone3GSK5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPhone_4:
			{
				self.K1 = kSFHumiditySensoriPhone4K1;
				self.K2 = kSFHumiditySensoriPhone4K2;
				self.K3 = kSFHumiditySensoriPhone4K3;
				self.K4 = kSFHumiditySensoriPhone4K4;
				self.K5 = kSFHumiditySensoriPhone4K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPhone_4S:
			{
				self.K1 = kSFHumiditySensoriPhone4SK1;
				self.K2 = kSFHumiditySensoriPhone4SK2;
				self.K3 = kSFHumiditySensoriPhone4SK3;
				self.K4 = kSFHumiditySensoriPhone4SK4;
				self.K5 = kSFHumiditySensoriPhone4SK5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPhone_5:
			case SFDeviceHardwarePlatform_iPhone_5C:
			case SFDeviceHardwarePlatform_iPhone_5S:
			case SFDeviceHardwarePlatform_iPod_Touch_5G:
			{
				self.K1 = kSFHumiditySensoriPhone5K1;
				self.K2 = kSFHumiditySensoriPhone5K2;
				self.K3 = kSFHumiditySensoriPhone5K3;
				self.K4 = kSFHumiditySensoriPhone5K4;
				self.K5 = kSFHumiditySensoriPhone5K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPod_Touch_4G:
			{
				self.K1 = kSFHumiditySensoriPod4K1;
				self.K2 = kSFHumiditySensoriPod4K2;
				self.K3 = kSFHumiditySensoriPod4K3;
				self.K4 = kSFHumiditySensoriPod4K4;
				self.K5 = kSFHumiditySensoriPod4K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPad_2:
			{
				self.K1 = kSFHumiditySensoriPad2K1;
				self.K2 = kSFHumiditySensoriPad2K2;
				self.K3 = kSFHumiditySensoriPad2K3;
				self.K4 = kSFHumiditySensoriPad2K4;
				self.K5 = kSFHumiditySensoriPad2K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPad_3:
			{
				self.K1 = kSFHumiditySensoriPad3K1;
				self.K2 = kSFHumiditySensoriPad3K2;
				self.K3 = kSFHumiditySensoriPad3K3;
				self.K4 = kSFHumiditySensoriPad3K4;
				self.K5 = kSFHumiditySensoriPad3K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPad_4:
			{
				self.K1 = kSFHumiditySensoriPad4K1;
				self.K2 = kSFHumiditySensoriPad4K2;
				self.K3 = kSFHumiditySensoriPad4K3;
				self.K4 = kSFHumiditySensoriPad4K4;
				self.K5 = kSFHumiditySensoriPad4K5;
				break;
			}
				
			case SFDeviceHardwarePlatform_iPad_Mini:
			case SFDeviceHardwarePlatform_iPad_Mini_Retina:
			case SFDeviceHardwarePlatform_iPad_Air:
			{
				self.K1 = kSFHumiditySensoriPadMiniK1;
				self.K2 = kSFHumiditySensoriPadMiniK2;
				self.K3 = kSFHumiditySensoriPadMiniK3;
				self.K4 = kSFHumiditySensoriPadMiniK4;
				self.K5 = kSFHumiditySensoriPadMiniK5;
				break;
			}
				
			default:
			{
				self.K1 = kSFHumiditySensoriPhone4K1;
				self.K2 = kSFHumiditySensoriPhone4K2;
				self.K3 = kSFHumiditySensoriPhone4K3;
				self.K4 = kSFHumiditySensoriPhone4K4;
				self.K5 = kSFHumiditySensoriPhone4K5;
				break;
			}
		}
		
	}
	return self;
}


- (void)dealloc {
	
	[self.simulationTimer invalidate];
	self.simulationTimer = nil;
	
	[self.signalProcessor stop];
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
		
		NSLog(@"SFHumiditySensor is not plugged in. Not able to switch on.");
		return;
	}
	
	// start with resetting
	_state = kSFHumiditySensorStateResetting;
	
	[self setOutputVolumeUp];
	
	// setup signal processor for resetting (00 signal)
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorResettingMeanSteps;
	[self.signalProcessor start];

	[super startCalibration];
}


- (void)calibrationComplete {
	
	[self.signalProcessor stop];
	[super calibrationComplete];
}


- (NSTimeInterval)calibrationTime {
	return SFHumiditySensorCalibrationDuration;
}


#pragma mark -
#pragma mark Measure


- (void)startMeasure {
	
	[super startMeasure];
	
	// setup for measure (11 signal)
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorHumidityMeanSteps;
	
	[self.signalProcessor start];
	
	// go on
	_state = kSFHumiditySensorStateHumidityMeasurement;
}


- (void)stopMeasure {
	
	[self.signalProcessor stop];
	_state = kSFHumiditySensorStateOff;
	
	[super stopMeasure];
}


- (void)didUpdateValue {
	
	if (_state == kSFHumiditySensorStateHumidityMeasurement ||
		_state == kSFHumiditySensorStateTemperatureMeasurement)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:nil];
		});
	}
}


#pragma mark -
#pragma mark Calculations


- (float)calculateTemparatureWithAmplitude:(Float32)amplitude trace:(BOOL)trace {
	
	// Т = (U2/U1)K1 – K2
	//
	// where:
	// U1 - calibrating level
	// U1 - temperature level
	// K1 and K2 - coefficients
	
	Float32 U1 = _calibratingLevel;
	Float32 U2 = amplitude;
	Float32 K1 = self.K1;
	Float32 K2 = self.K2;
	Float32 K5 = self.K5;
	
	Float32 T = K2 - K1 * (U2/U1);
	
	// under-zero temperature correction
	
	if (T < 0)
		T *= K5;
	
	return T;
}


- (float)calculateHumidityWithTemparature:(double)withTemperature amplitude:(Float32)amplitude trace:(BOOL)trace {
	
	// h = (U3 – K3) / К4 х 100
	// where U3 is humidity level
	// K3, K4 – coefficients
	
	Float32 U3 = amplitude;
	Float32 U4 = _secondCalibratingLevel;
	Float32 K3 = self.K3;
	Float32 K4 = self.K4;
	
	Float32 h = (U3 / U4 - K3) / K4 * 100;
	
	// temperature correction:
	// H  =  h/(1.0546 – 0.00216T)
	// where T - temperature in Cº
	// for now let's take 20º
	
	Float32 T = withTemperature;
	Float32 H = h/(1.0546 - 0.00216 * T);
	
	// limit by 0..100 range
	H = MAX(H, 0);
	H = MIN(H, 100);
	
	return H;
}


- (void)recalculateMeasures {
	
	// update temperature value
	_temperature = [self calculateTemparatureWithAmplitude:_temperatureLevel trace:NO];
	
	// notify
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:nil];
	});
	
	// update humidity
	_humidity = [self calculateHumidityWithTemparature:_temperature amplitude:_humidityLevel trace:NO];
}


#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	switch (_state) {
			
		case kSFHumiditySensorStateOff:
			break;
		
		case kSFHumiditySensorStateResetting:
		{	
			// setup for calibrating (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorCalibratingMeanSteps;
			
			_state = kSFHumiditySensorStateCalibrateMeasurement;
			
			break;
		}
		
		case kSFHumiditySensorStateCalibrateMeasurement:
		{
			// for calibrating let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save calibrating level
			_calibratingLevel = amplitude;
			
			// setup for second resetting (00 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorSecondResettingMeanSteps;
			
			_state = kSFHumiditySensorStateSecondResetting;
			
			break;
		}
			
		case kSFHumiditySensorStateSecondResetting:
		{
			// setup for second calibrating (11 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorCalibratingMeanSteps;
			
			_state = kSFHumiditySensorStateSecondCalibrateMeasurement;
			
			break;
		}
			
		case kSFHumiditySensorStateSecondCalibrateMeasurement:
		{
			// for calibrating let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save calibrating level
			_secondCalibratingLevel = amplitude;
			
			// setup for temperature (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorFirstTemperatureMeanSteps;
			
			_state = kSFHumiditySensorStateFirstTemperatureMeasurement;
			
			break;
		}
			
		case kSFHumiditySensorStateFirstTemperatureMeasurement:
		{
			// for temparature let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save temperature level
			_temperatureLevel = amplitude;
			
			// update temperature value
			_temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			[self calibrationComplete];
			
			break;
		}
			
		case kSFHumiditySensorStateTemperatureMeasurement:
		{
			// for temparature let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save temperature level
			_temperatureLevel = amplitude;
			
			// update temperature value
			_temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			// notify
			[self didUpdateValue];
			
			// setup for measure (11 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorHumidityMeanSteps;
			
			// go on
			_state = kSFHumiditySensorStateHumidityMeasurement;

			break;
		}
			
		case kSFHumiditySensorStateHumidityMeasurement:
		{
			// for humidity let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save humidity level
			_humidityLevel = amplitude;
			
			// update humidity
			_humidity = [self calculateHumidityWithTemparature:_temperature amplitude:amplitude trace:NO];
			
			// notify
			[self didUpdateValue];
			
			// setup for temperature (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorTemperatureMeanSteps;
			
			_state = kSFHumiditySensorStateTemperatureMeasurement;
			
			break;
		}
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark Utilities


- (void)setOutputVolumeUp {
	
	float outputVolume;
	id humidity_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"humidity_volume"];
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (humidity_volume) {
		outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"humidity_volume"];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	} else if (european_preference) {
		outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	}
}


#pragma mark -
#pragma mark Simulation


- (void)simulateCalibrationComplete {
	
	[self calibrationComplete];
	self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(simulateHumidityMeasure) userInfo:nil repeats:NO];
}


- (void)simulateHumidityMeasure {
	
	_humidity = 55.0 + 5.0 * RANDOM_0_1();
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:nil];
	});
	
	self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(simulateTemperatureMeasure) userInfo:nil repeats:NO];
}


- (void)simulateTemperatureMeasure {
	
	_temperature = 25.0 + 2.0 * RANDOM_0_1();
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:nil];
	});
	
	self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(simulateHumidityMeasure) userInfo:nil repeats:NO];
}


@end
