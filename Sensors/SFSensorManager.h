//
//	SenseFramework/SFSensorManager.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFIdentificator.h"
#import "SFAbstractSensor.h"


extern NSString *const SFSensorManagerWillStartSensorIdentification;
extern NSString *const SFSensorManagerDidFinishSensorIdentification;
extern NSString *const SFSensorManagerDidRecognizeSensorPluggedInNotification;
extern NSString *const SFSensorManagerDidRecognizeSensorPluggedOutNotification;
extern NSString *const SFSensorManagerNeedUserPermissionToSwitchToEU;


/*
 * List of all hardware platforms
 * which need specific SenseFramework settings
 */
typedef enum {
	SFDeviceHardwarePlatform_Default,
	SFDeviceHardwarePlatform_iPhone_5,
	SFDeviceHardwarePlatform_iPad_2
} SFDeviceHardwarePlatform;


@interface SFSensorManager : NSObject

@property (nonatomic, assign) BOOL activeMode;
@property (nonatomic, readonly) SFSensorType currentSensorType;
@property (nonatomic, assign) SFDeviceHardwarePlatform hardwarePlatform;

+ (SFSensorManager *)sharedManager;

/* 
 * use this method to update information about current sensor
 * in cases when manager didn't have chance to do it itself
 * on launch, on coming back from background, etc
 */
- (void)updateCurrentState;

/*
 * use this methods to confirm user's permission grant/pfohibit
 * on SFSensorManagerNeedUserPermissionToSwitchToEU
 */
- (void)userGrantedPermissionToSwitchToEU;
- (void)userProhibitedPermissionToSwitchToEU;



@end
