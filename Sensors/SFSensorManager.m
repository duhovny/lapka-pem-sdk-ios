//
//	SenseFramework/SFSensorManager.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFSensorManager.h"
#import "SFIdentificator.h"
#import "SFAudioSessionManager.h"
#import "SFFieldSensor.h"
#import "SFHumiditySensor.h"
#import "SFRadiationSensor.h"
#import "SFNitratesSensor.h"


// Notifications
NSString *const SFSensorManagerWillStartSensorIdentification = @"SFSensorManagerWillStartSensorIdentification";
NSString *const SFSensorManagerDidFinishSensorIdentification = @"SFSensorManagerDidFinishSensorIdentification";
NSString *const SFSensorManagerDidRecognizeSensorPluggedInNotification = @"SFSensorManagerDidRecognizeSensorPluggedInNotification";
NSString *const SFSensorManagerDidRecognizeSensorPluggedOutNotification = @"SFSensorManagerDidRecognizeSensorPluggedOutNotification";
NSString *const SFSensorManagerNeedUserPermissionToSwitchToEU = @"SFSensorManagerNeedUserPermissionToSwitchToEU";


@interface SFSensorManager () <SFIdentificatorDelegate>

@property (nonatomic, strong) SFIdentificator *identificator;
@property (nonatomic, strong) SFAbstractSensor *sensor;
@property (nonatomic, strong) SFSignalProcessor *signalProcessor;

- (void)setupActiveMode;
- (void)unsetupActiveMode;

@end


@implementation SFSensorManager


#pragma mark -
#pragma mark Singleton


+ (SFSensorManager *)sharedManager {
	static dispatch_once_t once;
	static SFSensorManager *sharedManager;
    dispatch_once(&once, ^{
        sharedManager = [[SFSensorManager alloc] init];
    });
    return sharedManager;
}


#pragma mark -
#pragma mark Lifecycle


- (id)init {
	self = [super init];
	if (self) {
		
		// default
		_activeMode = NO;
		_currentSensorType = SFSensorTypeUnknown;
		_hardwarePlatform = SFDeviceHardwarePlatform_iPhone_5;
	}
	return self;
}


- (void)dealloc {
	[self setActiveMode:NO];
}


#pragma mark -
#pragma mark Active Mode


- (void)setupActiveMode {
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeAudioRoute) name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
	
	[[SFAudioSessionManager sharedManager] activateAudioSession];
	
	self.identificator = [[SFIdentificator alloc] init];
	self.identificator.delegate = self;
}


- (void)unsetupActiveMode {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
	[[SFAudioSessionManager sharedManager] deactivateAudioSession];
	self.identificator = nil;
}


#pragma mark Active Mode Setter


- (void)setActiveMode:(BOOL)value {
	
	if (_activeMode == value) return;
	_activeMode = value;
	
	if (_activeMode) [self setupActiveMode];
	else [self unsetupActiveMode];
}


#pragma mark -
#pragma mark Sensor


- (SFAbstractSensor *)currentSensor {
	return _sensor;
}


- (void)createSensorWithType:(SFSensorType)sensorType {
	
	NSLog(@"create %@ sensor", [SFIdentificator sensorTypeToString:sensorType]);
	
	self.signalProcessor = [[SFSignalProcessor alloc] init];
	
	switch (sensorType) {
		case SFSensorTypeFields:
		{
			self.sensor = [[SFFieldSensor alloc] initWithSignalProcessor:_signalProcessor];
			break;
		}
		case SFSensorTypeNitrates:
		{
			self.sensor = [[SFNitratesSensor alloc] initWithSignalProcessor:_signalProcessor];
			break;
		}
		case SFSensorTypeRadiation:
		{
			self.sensor = [[SFRadiationSensor alloc] initWithSignalProcessor:_signalProcessor];
			break;
		}
		case SFSensorTypeHumidity:
		{
			self.sensor = [[SFHumiditySensor alloc] initWithSignalProcessor:_signalProcessor];
			break;
		}
		default:
			break;
	}
}


- (void)removeSensor {

	NSLog(@"remove sensor");
	
	[_sensor stopMeasure];
	
	self.sensor = nil;
	self.signalProcessor = nil;
}


#pragma mark -
#pragma mark Update


- (void)updateCurrentState {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		
		if (_currentSensorType != SFSensorTypeUnknown) {
			_currentSensorType = SFSensorTypeUnknown;
			
			[self removeSensor];
			
			NSLog(@"remove european_preference");
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"european_preference"];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
			});
		}
	} else {
		
		if (_currentSensorType == SFSensorTypeUnknown) {
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerWillStartSensorIdentification object:nil];
			});
			
			float delayInSeconds = 0.6;
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
			dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
				[self.identificator identificate];
			});
		}
	}
}


#pragma mark -
#pragma mark Identificator Delegate


- (void)identificatorDidRecognizeSensor:(SFSensorType)sensorType {
	
	BOOL sensorTypeHaveNotChanged = (sensorType == _currentSensorType);
	_currentSensorType = sensorType;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidFinishSensorIdentification object:nil];
	});
	
	if (sensorTypeHaveNotChanged) return;
	
	if (_currentSensorType == SFSensorTypeUnknown) {
		[self removeSensor];
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
		});
	} else {
		[self createSensorWithType:_currentSensorType];
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedInNotification object:nil];
		});
	}
}


#pragma mark -
#pragma mark Audio Session Notifications Listeners


- (void)audioSessionDidChangeAudioRoute {
	
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
	[self updateCurrentState];
}


#pragma mark -
#pragma mark Simulation


- (void)simulateSensorWithSensorType:(SFSensorType)sensorType {
	
	if (_isSensorSimulated || _currentSensorType) return;
	_isSensorSimulated = YES;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerWillStartSensorIdentification object:nil];
	});
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self identificatorDidRecognizeSensor:sensorType];
	});
}


- (void)simulateSensorPlugOut {
	
	if (_currentSensorType == SFSensorTypeUnknown) return;
	_currentSensorType = SFSensorTypeUnknown;
	
	[self removeSensor];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
	});
	
	_isSensorSimulated = NO;
}


@end
