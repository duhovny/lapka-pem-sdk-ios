//
//	SenseFramework/SFAbstractSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFAbstractSensor.h"
#import "SFAudioSessionManager.h"

@implementation SFAbstractSensor
@synthesize signalProcessor;
@synthesize delegate;


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
#pragma mark ON/OFF


- (void)switchOn {
	
	// override in real class
	// don't forget to call super
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	if ([self.delegate respondsToSelector:@selector(sensorDidSwitchOn:)]) {
		[self.delegate sensorDidSwitchOn:self];
	}
}


- (void)switchOff {
	
	// override in real class
	// don't forget to call super
	
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	
	if ([self.delegate respondsToSelector:@selector(sensorDidSwitchOff:)])
		[self.delegate sensorDidSwitchOff:self];
}


#pragma mark -
#pragma mark Audio Session Notifications


- (void)audioSessionDidChangeAudioRoute {
	
	if ([[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		[self switchOn];
	} else {
		[self switchOff];
	}
}


- (void)hardwareOutputVolumeDidChange {
	
	if (!self.isPluggedIn) return;
	
	SFAudioSessionManager *audioSessionManager = [SFAudioSessionManager sharedManager];
	if (audioSessionManager.audioRouteIsHeadsetInOut &&
		audioSessionManager.hardwareOutputVolume != audioSessionManager.currentRegionMaxVolume) {
		float step = audioSessionManager.currentRegionMaxVolume - audioSessionManager.hardwareOutputVolume;
		if (step < VOLUME_ADJUST_LIMIT) {
//			NSLog(@"adjust hardware volume (from %0.2f to %0.2f with %0.4f step)", audioSessionManager.hardwareOutputVolume, audioSessionManager.currentRegionMaxVolume, step);
//			[audioSessionManager setHardwareOutputVolumeToRegionMaxValue];
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
