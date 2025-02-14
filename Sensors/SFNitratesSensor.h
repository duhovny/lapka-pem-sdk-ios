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
	SFNitratesSensorStateFirstTemperatureMeasurement,
	SFNitratesSensorStateEmptyNitratesMeasurement,
	SFNitratesSensorStateCalibrationComplete,
	SFNitratesSensorStateNitratesMeasurement,
	SFNitratesSensorStateTemperatureMeasurement
} SFNitratesSensorState;


@interface SFNitratesSensor : SFAbstractSensor

@property (nonatomic, readonly) SFNitratesSensorState state;

@property (nonatomic) float productCoefficient;
@property (nonatomic) BOOL reduceSmallValueToZero;

@property (readonly) float calibration_level;
@property (readonly) float temperature_level;
@property (readonly) float empty_nitrates_level;
@property (readonly) float nitrates_level;

@property (readonly) float empty_nitrates;
@property (readonly) float nitrates;
@property (readonly) float temperature;

@property float K1;
@property float K2;
@property float K3;
@property float K4;

@end
