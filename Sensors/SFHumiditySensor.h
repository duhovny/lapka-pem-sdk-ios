//
//	SenseFramework/SFHumiditySensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFAbstractSensor.h"

typedef enum {
	kSFHumiditySensorStateOff = 0,
	kSFHumiditySensorStateResetting,
	kSFHumiditySensorStateCalibrateMeasurement,
	kSFHumiditySensorStateSecondResetting,
	kSFHumiditySensorStateSecondCalibrateMeasurement,
	kSFHumiditySensorStateFirstTemperatureMeasurement,
	kSFHumiditySensorStateHumidityMeasurement,
	kSFHumiditySensorStateTemperatureMeasurement
} SFHumiditySensorState;

@protocol SFHumiditySensorDelegate <SFAbstractSensorDelegate>
@optional
- (void)humiditySensorDidUpdateTemperature:(float)temperature;
- (void)humiditySensorDidUpdateFirstTemperature:(float)temperature;
- (void)humiditySensorDidUpdateCalibratingLevel:(float)calibratingLevel;
- (void)humiditySensorDidUpdateSecondCalibratingLevel:(float)secondCalibratingLevel;
- (void)humiditySensorDidUpdateMeanHumidity:(float)meanHumidity;
- (void)humiditySensorDidUpdateHumidity:(float)humidity;
@end

@interface SFHumiditySensor : SFAbstractSensor

@property (nonatomic, readonly) BOOL isOn;
@property (nonatomic, assign) NSObject <SFHumiditySensorDelegate> *delegate;
@property (nonatomic, readonly) SFHumiditySensorState state;

@property (nonatomic, readonly) double humidity;
@property (nonatomic, readonly) double temperature;

// unmodified signal levels
@property (nonatomic, readonly) float calibratingLevel;
@property (nonatomic, readonly) float secondCalibratingLevel;
@property (nonatomic, readonly) float temperatureLevel;
@property (nonatomic, readonly) float humidityLevel;

// temperature / humidity calculation coefs
@property float K1;
@property float K2;
@property float K3;
@property float K4;
@property float K5;

- (void)recalculateMeasures;

@end
