//
//	SenseFramework/SFHumiditySensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFHumiditySensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"

#define kSFHumiditySensorResettingMeanSteps	   250	// 5 sec
#define kSFHumiditySensorCalibratingMeanSteps	10	// 0.2 sec
#define kSFHumiditySensorFirstTemperatureMeanSteps  200	// 4 sec
#define kSFHumiditySensorTemperatureMeanSteps   50	// 1.0 sec
#define kSFHumiditySensorHumidityMeanSteps		50	// 1.0 sec

#define kSFHumiditySensorDefaultK1	53.0
#define kSFHumiditySensorDefaultK2	71.3
#define kSFHumiditySensorDefaultK3	0.073
#define kSFHumiditySensorDefaultK4	0.161


@implementation SFHumiditySensor

@synthesize isOn;
@synthesize state;
@synthesize delegate;
@synthesize humidity;
@synthesize temperature;
@synthesize calibratingLevel;
@synthesize temperatureLevel;
@synthesize humidityLevel;


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Humidity sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		self.K1 = kSFHumiditySensorDefaultK1;
		self.K2 = kSFHumiditySensorDefaultK2;
		self.K3 = kSFHumiditySensorDefaultK3;
		self.K4 = kSFHumiditySensorDefaultK4;
		
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
	if (humidity_volume) outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"humidity_volume"];
	else outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
	[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	
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
	
	if (trace) {
		NSLog(@"Calculate temparature: Т = (U2/U1)K1 – K2");
		NSLog(@"%f = (%f/%f)%f – %f", T, U2, U1, K1, K2);
	}
	
	return T;
}


- (float)calculateHumidityWithTemparature:(double)withTemperature amplitude:(Float32)amplitude trace:(BOOL)trace {
	
	// h = (U3 – K3) / К4 х 100
	// where U3 is humidity level
	// K3, K4 – coefficients
	
	Float32 U1 = calibratingLevel;
	Float32 U3 = amplitude;
	Float32 K3 = self.K3;
	Float32 K4 = self.K4;
	
	Float32 h = (U3 / (4 * U1) - K3) / K4 * 100;
	
	// temperature correction:
	// H  =  h/(1.0546 – 0.00216T)
	// where T - temperature in Cº
	// for now let's take 20º
	
	Float32 T = withTemperature;
	Float32 H = h/(1.0546 - 0.00216 * T);
	
	if (trace) {
		NSLog(@"---");
		
		NSLog(@"Calculate humidity: h = (U3 – K3) / К4 х 100");
		NSLog(@"%f = (%f – %0.3f) / %0.3f х 100", h, U3, K3, K4);
		
		NSLog(@"temperature correction: H  =  h/(1.0546 – 0.00216 x T)");
		NSLog(@"%f  =  %f/(1.0546 – 0.00216 x %0.1f)", H, h, T);
	}
	
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
			NSLog(@"Resetting done");
			
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
			
			NSLog(@"calibratingLevel: %f", calibratingLevel);
			
			// tell delegate
			if ([delegate respondsToSelector:@selector(humiditySensorDidUpdateCalibratingLevel:)])
				[delegate humiditySensorDidUpdateCalibratingLevel:calibratingLevel];
			
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
			
			// correct amplitude by subtract third bit identification amplitude
			float identification_third_bit_amplitude = [[NSUserDefaults standardUserDefaults] floatForKey:IDENTIFICATION_THIRD_BIT_AMPLITUDE_KEY];
			amplitude -= identification_third_bit_amplitude;
			
			// save temperature level
			temperatureLevel = amplitude;
			
			NSLog(@"temperatureLevel: %f", temperatureLevel);
			
			// update temperature value
			temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			NSLog(@"temperature: %f", temperature);
			
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
			
		case kSFHumiditySensorStateTemperatureMeasurement:
		{
			// for temparature let's take last (not mean) amplitude value
			float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// save temperature level
			temperatureLevel = amplitude;
			
			NSLog(@"temperatureLevel: %f", temperatureLevel);
			
			// update temperature value
			temperature = [self calculateTemparatureWithAmplitude:amplitude trace:NO];
			
			NSLog(@"temperature: %f", temperature);
			
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
			
//			NSLog(@"humidityLevel: %f", humidityLevel);
			
			// update humidity
			humidity = [self calculateHumidityWithTemparature:temperature amplitude:amplitude trace:NO];
			
//			NSLog(@"humidity: %f", humidity);
			
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
