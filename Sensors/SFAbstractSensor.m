//
//	SenseFramework/SFAbstractSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFAbstractSensor.h"
#import "SFAudioSessionManager.h"
#import "SFSensorManager.h"

NSString *const SFSensorWillStartCalibration = @"SFSensorWillStartCalibration";
NSString *const SFSensorDidCompleteCalibration = @"SFSensorDidCompleteCalibration";
NSString *const SFSensorWillStartMeasure = @"SFSensorWillStartMeasure";
NSString *const SFSensorDidCompleteMeasure = @"SFSensorDidCompleteMeasure";
NSString *const SFSensorDidUpdateMeanValue = @"SFSensorDidUpdateMeanValue";
NSString *const SFSensorDidUpdateValue = @"SFSensorDidUpdateValue";


@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@implementation SFAbstractSensor
@synthesize signalProcessor;


#define VOLUME_ADJUST_LIMIT 0.07


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	if ((self = [super init])) 
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hardwareOutputVolumeDidChange) name:SFHardwareOutputVolumeDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeAudioRoute) name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
		
		self.signalProcessor = aSignalProcessor;
		self.signalProcessor.delegate = self;
	}
	return self;
}


- (void)dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self name:SFHardwareOutputVolumeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
	self.signalProcessor = nil;
}


#pragma mark -
#pragma mark Calibration


- (void)startCalibration {
	
	// override in real class
	// don't forget to call super
	
	NSLog(@"Sensor will start calibration");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorWillStartCalibration object:nil];
	});
}


- (void)calibrationComplete {
	
	// override in real class
	// don't forget to call super
	
	NSLog(@"Sensor did complete calibration");
	
	_calibrated = YES;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidCompleteCalibration object:nil];
	});
}


#pragma mark -
#pragma mark Measure


- (void)startMeasure {
	
	// override in real class
	// don't forget to call super
	
	if (!_calibrated) {
		NSLog(@"Error: Sensor isn't calibrated — can't start measure");
		return;
	}
	
	NSLog(@"Sensor will start mesure");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorWillStartMeasure object:nil];
	});
	[UIApplication sharedApplication].idleTimerDisabled = YES;
}


- (void)stopMeasure {
	
	// override in real class
	// don't forget to call super
	
	NSLog(@"Sensor did finish measure");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidCompleteMeasure object:nil];
	});
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}


#pragma mark -
#pragma mark Audio Session Notifications


- (void)audioSessionDidChangeAudioRoute {
	
	if ([[SFSensorManager sharedManager] activeMode]) return;
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
	
	if ([[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		[self startMeasure];
	} else {
		[self stopMeasure];
	}
}


- (void)hardwareOutputVolumeDidChange {
	
	if (!self.isPluggedIn) return;
	
	SFAudioSessionManager *audioSessionManager = [SFAudioSessionManager sharedManager];
	SFSensorManager *sensorManager = [SFSensorManager sharedManager];
	if (audioSessionManager.audioRouteIsHeadsetInOut &&
		audioSessionManager.hardwareOutputVolume != audioSessionManager.currentRegionMaxVolume &&
		sensorManager.currentSensorType != SFSensorTypeUnknown) {
		float step = audioSessionManager.currentRegionMaxVolume - audioSessionManager.hardwareOutputVolume;
		if (step < VOLUME_ADJUST_LIMIT) {
			NSLog(@"adjust hardware volume (from %0.2f to %0.2f with %0.4f step)", audioSessionManager.hardwareOutputVolume, audioSessionManager.currentRegionMaxVolume, step);
			[audioSessionManager setHardwareOutputVolumeToRegionMaxValue];
		}
	}
}


#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	// refactor: this is not taking sensor type in account
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}


@end
