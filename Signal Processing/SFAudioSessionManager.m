//
//  SenseFramework/SFAudioSessionManager.m
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFAudioSessionManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>


NSString *const SFHardwareOutputVolumeDidChangeNotification = @"SFHardwareOutputVolumeDidChangeNotification";
NSString *const SFAudioSessionStartInterruptionNotification = @"SFAudioSessionStartInterruptionNotification";
NSString *const SFAudioSessionEndInterruptionNotification = @"SFAudioSessionEndInterruptionNotification";
NSString *const SFAudioSessionDidChangeAudioRouteNotification = @"SFAudioSessionDidChangeAudioRouteNotification";

#pragma mark -
#pragma mark Listeners Headers


void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState);


void audioVolumeChangeListenerCallback (
										void                      *inUserData,
										AudioSessionPropertyID    inID,
										UInt32                    inDataSize,
										const void                *inData);


void propListener(	void *                  inClientData,
                  AudioSessionPropertyID	inID,
                  UInt32                  inDataSize,
                  const void *            inData);


#pragma mark -
#pragma mark Listeners Bodies


void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	SFAudioSessionManager *audioSessionManager = (__bridge SFAudioSessionManager *)inClientData;
		
	switch (inInterruptionState) {
			
		case kAudioSessionBeginInterruption:
			[[NSNotificationCenter defaultCenter] postNotificationName:SFAudioSessionStartInterruptionNotification object:audioSessionManager];
			break;
			
		case kAudioSessionEndInterruption:
			[[NSNotificationCenter defaultCenter] postNotificationName:SFAudioSessionEndInterruptionNotification object:audioSessionManager];
			break;
			
		default:
			// unknown state, nothing happens
			break;
	}
}


void audioVolumeChangeListenerCallback (
										void                      *inUserData,
										AudioSessionPropertyID    inID,
										UInt32                    inDataSize,
										const void                *inData)
{
	SFAudioSessionManager *audioSessionManager = (__bridge SFAudioSessionManager *)inUserData;
	audioSessionManager->hardwareOutputVolume = *(Float32 *)inData;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SFHardwareOutputVolumeDidChangeNotification object:audioSessionManager];
}


void propListener(	void *                  inClientData,
                  AudioSessionPropertyID	inID,
                  UInt32                  inDataSize,
                  const void *            inData)
{
	// Get audio session manager
	SFAudioSessionManager *audioSessionManager = (__bridge SFAudioSessionManager *)inClientData;
	
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		// Get new route
		CFStringRef newRoute;
		UInt32 size = sizeof(CFStringRef);
		AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute);
		
		if (newRoute) {
			if (CFStringCompare(newRoute, CFSTR("HeadsetInOut"), 0) == kCFCompareEqualTo) {
				audioSessionManager->audioRouteIsHeadsetInOut = YES;
			} else {
				audioSessionManager->audioRouteIsHeadsetInOut = NO;
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:SFAudioSessionDidChangeAudioRouteNotification object:audioSessionManager];
		}
		CFRelease(newRoute);
	}	
}



@implementation SFAudioSessionManager
@synthesize hardwareOutputVolume;
@synthesize audioRouteIsHeadsetInOut;
@synthesize activated;


#pragma mark -
#pragma mark Singleton


+ (SFAudioSessionManager*)sharedManager {
	static dispatch_once_t once;
	static SFAudioSessionManager *sharedManager;
    dispatch_once(&once, ^{
        sharedManager = [[SFAudioSessionManager alloc] init];
    });
    return sharedManager;
}


#pragma mark -
#pragma mark Life Cycle


- (id)init {
	if ((self = [super init])) {
		
	}
	return self;
}


#pragma mark -
#pragma mark Audio Session Management


- (void)activateAudioSession {
	
	if (activated) return;
	
	NSLog(@"Activate Audio Session");
	
	OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, (__bridge void *)self);
	if (result == kAudioSessionNoError)
	{
		UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	}
	AudioSessionSetActive(true);
	
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, (__bridge void *)self);
	AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume, audioVolumeChangeListenerCallback, (__bridge void *)self);
	
	// check current route
	propListener((__bridge void*)self, kAudioSessionProperty_AudioRouteChange, 0, nil);
	
	// check current volume
	UInt32 size = sizeof(CFStringRef);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume, &size, &hardwareOutputVolume);
	
	activated = YES;
}


- (void)deactivateAudioSession {
	
	if (!activated) return;
	
	NSLog(@"Deactivate Audio Session");
	
	AudioSessionSetActive(false);
	activated = NO;
}


#pragma mark -
#pragma mark Hardware Output Volume


- (void)setHardwareOutputVolume:(Float32)value {
	
	if (hardwareOutputVolume == value) return;
	
	hardwareOutputVolume = value > 1.0 ? 1.0 : value;
	hardwareOutputVolume = value < 0.0 ? 0.0 : value;
	
	NSLog(@"setHardwareOutputVolume: %0.3f", hardwareOutputVolume);
	
	MPMusicPlayerController *musicPlayer = [MPMusicPlayerController iPodMusicPlayer];
	musicPlayer.volume = hardwareOutputVolume;
}


- (void)setHardwareOutputVolumeToRegionMaxValue {
	
	self.hardwareOutputVolume = self.currentRegionMaxVolume;
}


- (float)currentRegionMaxVolume {
	
	BOOL europeanRegion = [[NSUserDefaults standardUserDefaults] boolForKey:@"european_preference"];
	float regionMaxVolume = europeanRegion ? SFAudioSessionHardwareOutputVolumeEuropeanMax : SFAudioSessionHardwareOutputVolumeDefaultMax;
	return regionMaxVolume;
}


@end
