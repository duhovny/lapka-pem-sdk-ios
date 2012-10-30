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
NSString *const SFSensorManagerDidRecognizeSensorPluggedInNotification = @"SFSensorManagerDidRecognizeSensorPluggedInNotification";
NSString *const SFSensorManagerDidRecognizeSensorPluggedOutNotification = @"SFSensorManagerDidRecognizeSensorPluggedOutNotification";


@interface SFSensorManager () <SFIdentificatorDelegate>

@property (nonatomic, retain) SFIdentificator *identificator;

@end


@implementation SFSensorManager
@synthesize currentSensorType;
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
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeAudioRoute) name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
		
		[[SFAudioSessionManager sharedManager] activateAudioSession];
		
		self.identificator = [[SFIdentificator alloc] init];
		self.identificator.delegate = self;
		
	}
	return self;
}


- (void)dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:SFAudioSessionDidChangeAudioRouteNotification object:nil];
	[[SFAudioSessionManager sharedManager] deactivateAudioSession];
	self.identificator = nil;
}


#pragma mark -
#pragma mark Update


- (void)updateCurrentState {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		
		if (currentSensorType != SFSensorTypeUnknown) {
			self.currentSensorType = SFSensorTypeUnknown;
			[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
		}
	} else {
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerWillStartSensorIdentification object:nil];
		[self.identificator identificate];
	}
}


#pragma mark -
#pragma mark Identificator Delegate


- (void)identificatorDidRecognizeSensor:(SFSensorType)sensorType {
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidFinishSensorIdentification object:nil];
	
	if (currentSensorType == sensorType) return;
	self.currentSensorType = sensorType;
	
	if (currentSensorType == SFSensorTypeUnknown) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedOutNotification object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorManagerDidRecognizeSensorPluggedInNotification object:nil];
	}
}


#pragma mark -
#pragma mark Audio Session Notifications Listeners


- (void)audioSessionDidChangeAudioRoute {
	
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) return;
	[self updateCurrentState];
}



@end
