//
//	SenseFramework/SFAbstractSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFAbstractSensor.h"
#import "SFAudioSessionManager.h"
#import "SFSensorManager.h"

#define VOLUME_ADJUST_LIMIT 0.07


NSString *const SFSensorWillStartCalibration = @"SFSensorWillStartCalibration";
NSString *const SFSensorDidCompleteCalibration = @"SFSensorDidCompleteCalibration";
NSString *const SFSensorDidCancelCalibration = @"SFSensorDidCancelCalibration";
NSString *const SFSensorWillStartMeasure = @"SFSensorWillStartMeasure";
NSString *const SFSensorDidCompleteMeasure = @"SFSensorDidCompleteMeasure";
NSString *const SFSensorDidUpdateValue = @"SFSensorDidUpdateValue";
NSString *const SFSensorDidUpdateIntermediateValue = @"SFSensorDidUpdateIntermediateValue";


@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@implementation SFAbstractSensor


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


- (void)cancelCalibration {
	
	// override in real class
	// don't forget to call
	// [super cancelCalibration];
	
	NSLog(@"Sensor did cancel calibration");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidCancelCalibration object:nil];
	});
}


- (void)resetCalibration {
	
	_calibrated = NO;
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
	
	if (_measuring) return;
	_measuring = YES;
	
	NSLog(@"Sensor will start mesure");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorWillStartMeasure object:nil];
	});
	[UIApplication sharedApplication].idleTimerDisabled = YES;
}


- (void)stopMeasure {
	
	// override in real class
	// don't forget to call super
	
	if (!_measuring) return;
	_measuring = NO;
	
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
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}


#pragma mark -
#pragma mark State


- (SFSensorState)sensorState {
	
	NSLog(@"Warning: sensorState should be overrided");
	return SFSensorStateOff;
}


@end
