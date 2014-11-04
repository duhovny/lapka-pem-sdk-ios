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
	SFDeviceHardwarePlatform_Unknown,
	SFDeviceHardwarePlatform_iPhone_3GS,
	SFDeviceHardwarePlatform_iPhone_4,
	SFDeviceHardwarePlatform_iPhone_4S,
	SFDeviceHardwarePlatform_iPhone_5,
	SFDeviceHardwarePlatform_iPhone_5C,
	SFDeviceHardwarePlatform_iPhone_5S,
	SFDeviceHardwarePlatform_iPod_Touch_4G,
	SFDeviceHardwarePlatform_iPod_Touch_5G,
	SFDeviceHardwarePlatform_iPad_2,
	SFDeviceHardwarePlatform_iPad_3,
	SFDeviceHardwarePlatform_iPad_4,
	SFDeviceHardwarePlatform_iPad_Mini,
	SFDeviceHardwarePlatform_iPad_Air,
	SFDeviceHardwarePlatform_iPad_Mini_Retina
} SFDeviceHardwarePlatform;

@interface SFSensorManager : NSObject

@property (nonatomic) BOOL activeMode;
@property (nonatomic, readonly) SFSensorType currentSensorType;
@property (nonatomic, readonly) SFAbstractSensor *currentSensor;
@property (nonatomic) SFDeviceHardwarePlatform hardwarePlatform;
@property (nonatomic, readonly) BOOL isSensorSimulated;

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

/*
 * use this method when app fall asleep with sensor
 * and don't know what is plugged in on wake up
 */
- (void)simulateSensorPlugOut;

/*
 * sensor simulation — for debug only
 * for unplug simulation, use simulateSensorPlugOut method
 */
- (void)simulateSensorWithSensorType:(SFSensorType)sensorType;


@end
