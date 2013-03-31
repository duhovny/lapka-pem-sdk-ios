//
//	SenseFramework/SFSensorManager.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFSensorManager.h"
#import "SFIdentificator.h"
#import "SFAudioSessionManager.h"


// Notifications
NSString *const SFSensorManagerWillStartSensorIdentification = @"SFSensorManagerWillStartSensorIdentification";
NSString *const SFSensorManagerDidFinishSensorIdentification = @"SFSensorManagerDidFinishSensorIdentification";
NSString *const SFSensorManagerDidRecognizeNotLapkaPluggedInNotification = @"SFSensorManagerDidRecognizeNotLapkaPluggedInNotification";
NSString *const SFSensorManagerDidRecognizeSensorPluggedInNotification = @"SFSensorManagerDidRecognizeSensorPluggedInNotification";
NSString *const SFSensorManagerDidRecognizeSensorPluggedOutNotification = @"SFSensorManagerDidRecognizeSensorPluggedOutNotification";
NSString *const SFSensorManagerNeedUserPermissionToSwitchToEU = @"SFSensorManagerNeedUserPermissionToSwitchToEU";


@interface SFSensorManager () <SFIdentificatorDelegate>

@property (nonatomic, retain) SFIdentificator *identificator;

- (void)setupActiveMode;
- (void)unsetupActiveMode;

@end


@implementation SFSensorManager
@synthesize identificator;


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
		_hardwarePlatform = SFDeviceHardwarePlatform_Default;
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
#pragma mark Update


- (void)updateCurrentState {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		
		if (_currentSensorType != SFSensorTypeUnknown) {
			_currentSensorType = SFSensorTypeUnknown;
			NSLog(@"remove european_preference");
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"european_preference"];
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
		}
	} else {
		
		if (_currentSensorType == SFSensorTypeUnknown) {
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerWillStartSensorIdentification object:nil];
			float delayInSeconds = 0.1;
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
			dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
				[self.identificator identificate];
			});
		}
	}
}


#pragma mark -
#pragma mark EU Switch Permission


- (void)userGrantedPermissionToSwitchToEU {
	
	[identificator userGrantedPermissionToSwitchToEU];
}


- (void)userProhibitedPermissionToSwitchToEU {
	
	[identificator userProhibitedPermissionToSwitchToEU];
}


#pragma mark -
#pragma mark Plug Out Simulation


- (void)simulateSensorPlugOut {
	
	if (_currentSensorType == SFSensorTypeUnknown) return;
	[self identificatorDidRecognizeSensor:SFSensorTypeUnknown];
}


#pragma mark -
#pragma mark Identificator Delegate


- (void)identificatorDidRecognizeSensor:(SFSensorType)sensorType {
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidFinishSensorIdentification object:nil];
	
	if (_currentSensorType == sensorType) return;
	_currentSensorType = sensorType;
	
	if (_currentSensorType == SFSensorTypeUnknown) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedInNotification object:nil];
	}
}


- (void)identificatorDidRecognizeNotLapkaBeingPluggedIn {
	
	NSLog(@"identificatorDidRecognizeNotLapkaBeingPluggedIn");
	[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeNotLapkaPluggedInNotification object:nil];
	
	[identificator abortIdentification];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidFinishSensorIdentification object:nil];
}


- (void)identificatorAskToGrantPermissionToSwitchToEU {
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerNeedUserPermissionToSwitchToEU object:nil];
}


#pragma mark -
#pragma mark Audio Session Notifications Listeners


- (void)audioSessionDidChangeAudioRoute {
	
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
	[self updateCurrentState];
}



@end
