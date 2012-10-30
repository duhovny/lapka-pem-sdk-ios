//
//	SenseFramework/SFNitratesSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFAbstractSensor.h"


typedef enum {
	SFNitratesSensorStateOff = 0,
	SFNitratesSensorStateSafeDelay,
	SFNitratesSensorStateCalibration,
	SFNitratesSensorStateTemperatureMeasurement,
	SFNitratesSensorStateNitratesMeasurement
} SFNitratesSensorState;

@protocol SFNitratesSensorDelegate <SFAbstractSensorDelegate>
- (void)nitratesSensorGotNitrates:(float)nitrates;
@end


@interface SFNitratesSensor : SFAbstractSensor {
	
}

@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, readonly) BOOL isOn;
@property (nonatomic, assign) NSObject <SFNitratesSensorDelegate> *delegate;
@property (nonatomic, readonly) SFNitratesSensorState state;

@property (readonly) float calibration_level;
@property (readonly) float temperature_level;
@property (readonly) float nitrates_level;

@property (readonly) float nitrates;
@property (readonly) float temperature;

@property float K1;
@property float K2;
@property float K3;
@property float K4;

- (void)restart;

@end
