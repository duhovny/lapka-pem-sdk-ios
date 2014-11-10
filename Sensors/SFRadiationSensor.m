//
//	SenseFramework/SFRadiationSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFRadiationSensor.h"
#import "SFSignalImpulseDetector.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFRadiationSensorFrequency		19000
#define kSFRadiationSensorAmplitude		1.0
#define kSFRadiationSensorMeanSteps		50
#define kSFRadiationImpulseTreshold		0.3
#define kSFRadiationSensorSafeStartTime	1.0
#define kSFRadiationParticlesPerMinuteToMicrosievertsPerHourCoef 0.04
#define kSFRadiationParticlesPerMinuteToMicrorentgensPerHourCoef 4.0
#define SFRadiationSensorMeanAmplitudeToImpulseTresholdCoef 4.0
#define kSFRadiationSensorCalibrationTime 4.0

#define RANDOM_0_1() ((random() / (float)0x7fffffff))


@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@interface SFRadiationSensor ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *calibrationTimer;
@property (nonatomic, strong) NSTimer *simulationTimer;
@end


@implementation SFRadiationSensor


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	NSLog(@"Radiation sensor init");
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		self.signalProcessor.impulseDetector.threshold = kSFRadiationImpulseTreshold;
		self.signalProcessor.frequency = kSFRadiationSensorFrequency;
	}
	return self;
}


- (void)dealloc {
	
	[self.timer invalidate];
	self.timer = nil;
	
	[self.simulationTimer invalidate];
	self.simulationTimer = nil;
	
	[self.calibrationTimer invalidate];
	self.calibrationTimer = nil;
}


#pragma mark -
#pragma mark Calibration


- (void)startCalibration {
	
	self.calibrationTimer = [NSTimer scheduledTimerWithTimeInterval:self.calibrationTime target:self selector:@selector(calibrationComplete) userInfo:nil repeats:NO];
	[super startCalibration];
}


- (NSTimeInterval)calibrationTime {
	return kSFRadiationSensorCalibrationTime;
}


#pragma mark -
#pragma mark Measure


- (void)startMeasure {
	
	if (![self isPluggedIn]) {
		
		BOOL iamSimulated = [[SFSensorManager sharedManager] isSensorSimulated];
		if (iamSimulated) {
			
			[super startMeasure];
			
			self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
			[self simulateParticleAndScheduleNext];
			
			return;
		}
		
		NSLog(@"SFRadiationSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	[super startMeasure];
	
	[self setOutputVolumeUp];
	
	// setup signal processor
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.impulseDetectorEnabled = YES;
	self.signalProcessor.fftAnalyzerEnabled = NO;
	[self.signalProcessor start];
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}


- (void)stopMeasure {
	
	[self.calibrationTimer invalidate];
	self.calibrationTimer = nil;
	
	[self.simulationTimer invalidate];
	self.simulationTimer = nil;
	
	[self.timer invalidate];
	self.timer = nil;
	
	[self.signalProcessor stop];
	_particles = 0;
	_time = 0;
	
	[super stopMeasure];
}


#pragma mark -
#pragma mark Particles


- (double)particlesPerMinute {
	
	double value;
	
	if (time > 0) {
		float minutes = _time / 60.0;
		value = _particles / minutes;
	} else {
		value = 0.0;
	}
	
	return value;
}


#pragma mark -
#pragma mark Radiation Level


- (double)radiationLevel {
	
	float microsievertsPerHour = [self convertParticlesPerMinutesToMicrosievertsPerHour:self.particlesPerMinute];
	return microsievertsPerHour;
}


#pragma mark -
#pragma mark Report


- (void)reportRadiationLevelUpdate {
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@([self radiationLevel])];
	});
}


#pragma mark -
#pragma mark Timer


- (void)tick {
	
	_time++;
	[self reportRadiationLevelUpdate];
}


#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidRecognizeImpulse {
	
	if (_time < kSFRadiationSensorSafeStartTime) {
		NSLog(@"~ r ignore particle at safe time");
		return;
	} else {
		NSLog(@"~ r register particle");
	}
	
	_particles++;
	[self reportRadiationLevelUpdate];
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	float impulseThreshold = meanAmplitude * SFRadiationSensorMeanAmplitudeToImpulseTresholdCoef;
	self.signalProcessor.impulseDetector.threshold = impulseThreshold;
}


#pragma mark -
#pragma mark Utilities


- (void)setOutputVolumeUp {

	float outputVolume;
	id radiation_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"radiation_volume"];
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (radiation_volume) {
		outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"radiation_volume"];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	} else if (european_preference) {
		outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	}
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


#pragma mark -
#pragma mark Simulate


- (void)simulateParticleAndScheduleNext {
	
	[self signalProcessorDidRecognizeImpulse];
	
	float timeBeforeNextParticle = (60.0 / 8) * (1 + RANDOM_0_1());
	self.simulationTimer = [NSTimer scheduledTimerWithTimeInterval:timeBeforeNextParticle target:self selector:@selector(simulateParticleAndScheduleNext) userInfo:nil repeats:NO];
}


@end
