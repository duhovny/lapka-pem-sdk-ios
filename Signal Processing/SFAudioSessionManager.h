//
//  SenseFramework/SFAudioSessionManager.h
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import <Foundation/Foundation.h>

#define SFAudioSessionHardwareOutputVolumeDefaultMax  0.83f
#define SFAudioSessionHardwareOutputVolumeEuropeanMax 1.0f

extern NSString *const SFHardwareOutputVolumeDidChangeNotification;
extern NSString *const SFAudioSessionStartInterruptionNotification;
extern NSString *const SFAudioSessionEndInterruptionNotification;
extern NSString *const SFAudioSessionDidChangeAudioRouteNotification;


@interface SFAudioSessionManager : NSObject {
@public
	Float32 hardwareOutputVolume;
	BOOL audioRouteIsHeadsetInOut;
}

@property (nonatomic, assign) Float32 hardwareOutputVolume;
@property (nonatomic, readonly) BOOL audioRouteIsHeadsetInOut;
@property (nonatomic, readonly) float currentRegionMaxVolume;
@property (nonatomic, readonly) BOOL activated;

// Singleton
+ (SFAudioSessionManager*)sharedManager;

- (void)activateAudioSession;
- (void)deactivateAudioSession;

- (void)setHardwareOutputVolumeToRegionMaxValue;

@end
