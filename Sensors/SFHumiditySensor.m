//
//	SenseFramework/SFHumiditySensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFHumiditySensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFHumiditySensorResettingMeanSteps	   250	// 5 sec
#define kSFHumiditySensorCalibratingMeanSteps	10	// 0.2 sec
#define kSFHumiditySensorSecondResettingMeanSteps	25	// 0.5 sec
#define kSFHumiditySensorFirstTemperatureMeanSteps  200	// 4 sec
#define kSFHumiditySensorTemperatureMeanSteps   50	// 1.0 sec
#define kSFHumiditySensorHumidityMeanSteps		50	// 1.0 sec

#define kSFHumiditySensorDefaultK1	104.0
#define kSFHumiditySensorDefaultK2	 68.6
#define kSFHumiditySensorDefaultK3	0.298
#define kSFHumiditySensorDefaultK4	1.026

#define kSFHumiditySensoriPhone5K1	103.4
#define kSFHumiditySensoriPhone5K2	 68.5
#define kSFHumiditySensoriPhone5K3	0.241
#define kSFHumiditySensoriPhone5K4	1.109

#define kSFHumiditySensoriPad2K1	104.0
#define kSFHumiditySensoriPad2K2	 64.4
#define kSFHumiditySensoriPad2K3	0.294
#define kSFHumiditySensoriPad2K4	1.026

#define kSFHumiditySensoriPadMiniK1	144.4
#define kSFHumiditySensoriPadMiniK2	 91.6
#define kSFHumiditySensoriPadMiniK3	0.319
#define kSFHumiditySensoriPadMiniK4	1.095

#define kSFHumiditySensoriPod4K1	103.5
#define kSFHumiditySensoriPod4K2	 67.9
#define kSFHumiditySensoriPod4K3	0.297
#define kSFHumiditySensoriPod4K4	1.039


@implementation SFHumiditySensor

@synthesize isOn;
@synthesize state;
@synthesize delegate;
@synthesize humidity;
@synthesize temperature;
@synthesize calibratingLevel;
@synthesize secondCalibratingLevel;
@synthesize temperatureLevel;
@synthesize humidityLevel;


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Humidity sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		if (hardwarePlatform == SFDeviceHardwarePlatform_iPhone_5) {
			self.K1 = kSFHumiditySensoriPhone5K1;
			self.K2 = kSFHumiditySensoriPhone5K2;
			self.K3 = kSFHumiditySensoriPhone5K3;
			self.K4 = kSFHumiditySensoriPhone5K4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPad) {
			self.K1 = kSFHumiditySensoriPad2K1;
			self.K2 = kSFHumiditySensoriPad2K2;
			self.K3 = kSFHumiditySensoriPad2K3;
			self.K4 = kSFHumiditySensoriPad2K4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPad_Mini) {
			self.K1 = kSFHumiditySensoriPadMiniK1;
			self.K2 = kSFHumiditySensoriPadMiniK2;
			self.K3 = kSFHumiditySensoriPadMiniK3;
			self.K4 = kSFHumiditySensoriPadMiniK4;
		} else if (hardwarePlatform == SFDeviceHardwarePlatform_iPod) {
			self.K1 = kSFHumiditySensoriPod4K1;
			self.K2 = kSFHumiditySensoriPod4K2;
			self.K3 = kSFHumiditySensoriPod4K3;
			self.K4 = kSFHumiditySensoriPod4K4;
		} else {
			self.K1 = kSFHumiditySensorDefaultK1;
			self.K2 = kSFHumiditySensorDefaultK2;
			self.K3 = kSFHumiditySensorDefaultK3;
			self.K4 = kSFHumiditySensorDefaultK4;
		}
		
	}
	return self;
}


- (void)dealloc {
	
}


#pragma mark -
#pragma mark ON/OFF


- (void)switchOn {
	
	if (![self isPluggedIn]) { NSLog(@"SFHumiditySensor is not plugged in. Not able to switch on."); return; }
	if ([self isOn]) { NSLog(@"SFHumiditySensor is already on."); return; }
	
	// start with resetting
	state = kSFHumiditySensorStateResetting;
	isOn = YES;
	
	// set volume up
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
	
	// setup signal processor for resetting (00 signal)
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorResettingMeanSteps;
	[self.signalProcessor start];
	
	[super switchOn];
}


- (void)switchOff {
	
	[self.signalProcessor stop];
	state = kSFHumiditySensorStateOff;
	isOn = NO;
	humidity = 0.0;
	temperature = 0.0;
	
	[super switchOff];
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
	
	Float32 U1 = calibratingLevel;
	Float32 U2 = amplitude;
	Float32 K1 = self.K1;
	Float32 K2 = self.K2;
	
	Float32 T = K2 - K1 * (U2/U1);
	
	return T;
}


- (float)calculateHumidityWithTemparature:(double)withTemperature amplitude:(Float32)amplitude trace:(BOOL)trace {
	
	// h = (U3 – K3) / К4 х 100
	// where U3 is humidity level
	// K3, K4 – coefficients
	
	Float32 U3 = amplitude;
	Float32 U4 = secondCalibratingLevel;
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
	temperature = [self calculateTemparatureWithAmplitude:temperatureLevel trace:NO];
	
	// tell delegate
	if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateTemperature:)])
		[delegate humiditySensorDidUpdateTemperature:temperature];
	
	// update humidity
	humidity = [self calculateHumidityWithTemparature:temperature amplitude:humidityLevel trace:NO];
}


#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	switch (state) {
			
		case kSFHumiditySensorStateOff:
			NSLog(@"Warning: SFHumiditySensor get measure result when off.");
			break;
		
		case kSFHumiditySensorStateResetting:
		{	
			// setup for calibrating (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorCalibratingMeanSteps;
			
			state = kSFHumiditySensorStateCalibrateMeasurement;
			
			break;
		}
		
		case kSFHumiditySensorStateCalibrateMeasurement:
		{
			// for calibrating let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save calibrating level
			calibratingLevel = amplitude;
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateCalibratingLevel:)])
				[delegate humiditySensorDidUpdateCalibratingLevel:calibratingLevel];
			
			// setup for second resetting (00 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorSecondResettingMeanSteps;
			
			state = kSFHumiditySensorStateSecondResetting;
			
			break;
		}
			
		case kSFHumiditySensorStateSecondResetting:
		{
			// setup for second calibrating (11 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorCalibratingMeanSteps;
			
			state = kSFHumiditySensorStateSecondCalibrateMeasurement;
			
			break;
		}
			
		case kSFHumiditySensorStateSecondCalibrateMeasurement:
		{
			// for calibrating let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save calibrating level
			secondCalibratingLevel = amplitude;
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateSecondCalibratingLevel:)])
				[delegate humiditySensorDidUpdateSecondCalibratingLevel:secondCalibratingLevel];
			
			// setup for temperature (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorFirstTemperatureMeanSteps;
			
			state = kSFHumiditySensorStateFirstTemperatureMeasurement;
			
			break;
		}
			
		case kSFHumiditySensorStateFirstTemperatureMeasurement:
		{
			// for temparature let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save temperature level
			temperatureLevel = amplitude;
			
			// update temperature value
			temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateFirstTemperature:)])
				[delegate humiditySensorDidUpdateFirstTemperature:temperature];
			
			// setup for measure (11 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorHumidityMeanSteps;
			
			// go on
			state = kSFHumiditySensorStateHumidityMeasurement;
			
			break;
		}
			
		case kSFHumiditySensorStateTemperatureMeasurement:
		{
			// for temparature let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save temperature level
			temperatureLevel = amplitude;
			
			// update temperature value
			temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateTemperature:)])
				[delegate humiditySensorDidUpdateTemperature:temperature];
			
			// setup for measure (11 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorHumidityMeanSteps;
			
			// go on
			state = kSFHumiditySensorStateHumidityMeasurement;

			break;
		}
			
		case kSFHumiditySensorStateHumidityMeasurement:
		{
			// for humidity let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save humidity level
			humidityLevel = amplitude;
			
			// update humidity
			humidity = [self calculateHumidityWithTemparature:temperature amplitude:amplitude trace:NO];
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateMeanHumidity:)])
				[delegate humiditySensorDidUpdateMeanHumidity:humidity];
			
			// setup for temperature (01 signal)
			self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
			self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
			self.signalProcessor.fftAnalyzer.meanSteps = kSFHumiditySensorTemperatureMeanSteps;
			
			state = kSFHumiditySensorStateTemperatureMeasurement;
			
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	
	if (state == kSFHumiditySensorStateHumidityMeasurement) {
		if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateHumidity:)]) {
			float currentHumidity = [self calculateHumidityWithTemparature:temperature amplitude:amplitude trace:NO];
			[delegate humiditySensorDidUpdateHumidity:currentHumidity];
		}
	}
}


#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	// refactor: this is not taking sensor type in account, move to abstract in that case
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}


@end
