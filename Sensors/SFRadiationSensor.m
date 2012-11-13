//
//	SenseFramework/SFRadiationSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFRadiationSensor.h"
#import "SFSignalImpulseDetector.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"

#define kSFRadiationSensorFrequency		19000
#define kSFRadiationSensorAmplitude		1.0
#define kSFRadiationSensorMeanSteps		50
#define kSFRadiationImpulseTreshold		0.3
#define kSFRadiationSensorSafeStartTime	1.0
#define kSFRadiationParticlesPerMinuteToMicrosievertsPerHourCoef 0.04
#define kSFRadiationParticlesPerMinuteToMicrorentgensPerHourCoef 4.0
#define SFRadiationSensorMeanAmplitudeToImpulseTresholdCoef 4.0


@implementation SFRadiationSensor

@dynamic delegate;
@synthesize state;
@synthesize isOn;

@synthesize timer;
@synthesize time;
@synthesize particles;
@synthesize impulseThreshold;
@synthesize useSievert;



#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Radiation sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		self.impulseThreshold = kSFRadiationImpulseTreshold;
		self.signalProcessor.frequency = kSFRadiationSensorFrequency;
	}
	return self;
}


- (void)dealloc {
	
	[self.timer invalidate];
	self.timer = nil;
}


#pragma mark -
#pragma mark ON/OFF


- (void)switchOn {
	
	if (![self isPluggedIn]) {
		NSLog(@"SFRadiationSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	if ([self isOn]) {
		NSLog(@"SFRadiationSensor is already on.");
		return;
	}
	
	// set volume up
	float outputVolume;
	id radiation_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"radiation_volume"];
	if (radiation_volume) outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"radiation_volume"];
	else outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
	[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	
	// setup signal processor
//	self.signalProcessor.frequency = kSFRadiationSensorFrequency;
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.impulseDetectorEnabled = YES;
	self.signalProcessor.fftAnalyzerEnabled = NO;
	
	[self.signalProcessor start];
	state = kSFRadiationSensorStateOn;
	isOn = YES;
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
	
	[super switchOn];
}


- (void)switchOff {
	
	[self.timer invalidate];
	self.timer = nil;
	
	[self.signalProcessor stop];
	state = kSFRadiationSensorStateOff;
	isOn = NO;
	particles = 0;
	time = 0;
	
	[super switchOff];
}


- (void)reset {
	
	time = 0;
	particles = 0;
	
	if (isOn) {
		[self reportRadiationLevelUpdate];
	}
}


#pragma mark -
#pragma mark Particles


- (double)particlesPerMinute {
	
	double value;
	
	if (time > 0) {
		float minutes = time / 60.0;
		value = particles / minutes;
	} else {
		value = 0.0;
	}
	
	return value;
}


#pragma mark -
#pragma mark Radiation Level


- (double)radiationLevel {
	
	float level;
	if (useSievert) {
		float microsievertsPerHour = [self convertParticlesPerMinutesToMicrosievertsPerHour:self.particlesPerMinute];
		level = microsievertsPerHour;
	} else {
		float microrentgensPerHour = [self convertParticlesPerMinutesToMicrorentgensPerHour:self.particlesPerMinute];
		level = microrentgensPerHour;
	}
	return level;
}


#pragma mark -
#pragma mark Report


- (void)reportRadiationLevelUpdate {
	
	[self.delegate radiationSensorDidUpdateRadiation:self.radiationLevel];
}


#pragma mark -
#pragma mark Timer


- (void)tick {
	
	time++;
	[self reportRadiationLevelUpdate];
}


#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidRecognizeImpulse {
	
	if (time < kSFRadiationSensorSafeStartTime) {
		NSLog(@"~ r ignore particle at safe time");
		return;
	} else {
		NSLog(@"~ r register particle");
	}
	
	particles++;
	[self reportRadiationLevelUpdate];
	
	if ([self.delegate respondsToSelector:@selector(radiationSensorDidRecognizeImpulse:)])
		[self.delegate radiationSensorDidRecognizeImpulse:self.signalProcessor.impulseDetector.impulseAmplitude];
}


- (void)signalProcessorDidUpdateMaxAmplitude:(Float32)maxAmplitude {
	
	switch (state) {
			
		case kSFRadiationSensorStateOff:
			NSLog(@"Warning: SFRadiationSensor get measure result when off.");
			break;
			
		case kSFRadiationSensorStateOn:
		{
//			NSLog(@"max: %f", maxAmplitude);
			if ([self.delegate respondsToSelector:@selector(radiationSensorDidUpdateMaxSignalAmplitude:)])
				[self.delegate radiationSensorDidUpdateMaxSignalAmplitude:maxAmplitude];
			
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	switch (state) {
			
		case kSFRadiationSensorStateOff:
			NSLog(@"Warning: SFRadiationSensor get something when off.");
			break;
			
		case kSFRadiationSensorStateOn:
		{	
			impulseThreshold = meanAmplitude * SFRadiationSensorMeanAmplitudeToImpulseTresholdCoef;
			self.signalProcessor.impulseDetector.threshold = impulseThreshold;
			
			if ([self.delegate respondsToSelector:@selector(radiationSensorDidUpdateImpulseTreshold:)])
				[self.delegate radiationSensorDidUpdateImpulseTreshold:impulseThreshold];
			
			break;
		}
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark Setters


- (void)setImpulseThreshold:(float)value {
	
	impulseThreshold = value;
	self.signalProcessor.impulseDetector.threshold = value;
}


#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	// refactor: this is not taking sensor type in account
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}


#pragma mark -
#pragma mark Convertion


- (float)convertParticlesPerMinutesToMicrosievertsPerHour:(float)ppm {
	
	float microsievertsPerHour = kSFRadiationParticlesPerMinuteToMicrosievertsPerHourCoef * ppm;
	return microsievertsPerHour;
}


- (float)convertParticlesPerMinutesToMicrorentgensPerHour:(float)ppm {
	
	float microrentgensPerHour = kSFRadiationParticlesPerMinuteToMicrorentgensPerHourCoef * ppm;
	return microrentgensPerHour;
}


@end
