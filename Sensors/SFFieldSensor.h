//
//	SenseFramework/SFFieldSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFAbstractSensor.h"


typedef enum {
	kSFFieldSensorStateOff = 0,
	kSFFieldSensorStateLowFrequencyMeasurement,
	kSFFieldSensorStateHighFrequencyMeasurement
} SFFieldSensorState;


@interface SFFieldSensor : SFAbstractSensor

@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, readonly) BOOL isOn;
@property (nonatomic, readonly) SFFieldSensorState state;
@property (nonatomic, assign) BOOL measureLowFrequencyField;
@property (nonatomic, assign) BOOL measureHighFrequencyField;
@property (nonatomic, readonly) float smallestHighFrequencyAmplitude;

@property (nonatomic, assign) float scaleCoef;
@property (nonatomic, assign) float hf_K1;
@property (nonatomic, assign) float hf_K2;
@property (nonatomic, assign) float lf_K1;
@property (nonatomic, assign) float lf_K2;

// measures
@property (nonatomic, readonly) float lowFrequencyField;
@property (nonatomic, readonly) float highFrequencyField;
@property (nonatomic, readonly) float meanLowFrequencyField;
@property (nonatomic, readonly) float meanHighFrequencyField;

// noize vector correction
- (void)enableFFTNoizeVectorCorrection;
- (void)disableFFTNoizeVectorCorrection;
- (void)resetFFTNoizeVectorCorrection;

@end
