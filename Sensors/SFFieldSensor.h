//
//	SenseFramework/SFFieldSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFAbstractSensor.h"


typedef enum {
	SFFieldSensorStateOff,
	SFFieldSensorStateCalibrating,
	SFFieldSensorStateReady,
	SFFieldSensorStateMeasuring
} SFFieldSensorState;

typedef enum {
	SFFieldTypeLowFrequency,
	SFFieldTypeHighFrequency
} SFFieldType;


@interface SFFieldSensor : SFAbstractSensor

@property (nonatomic, readonly) SFFieldSensorState state;
@property (nonatomic, readonly) SFFieldType fieldType;
@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, readonly) float smallestHighFrequencyAmplitude;

@property (nonatomic, assign) float scaleCoef;
@property (nonatomic, assign) float hf_K1;
@property (nonatomic, assign) float hf_K2;
@property (nonatomic, assign) float lf_K1;
@property (nonatomic, assign) float lf_K2;

// measure values
@property (nonatomic, readonly) float lowFrequencyField;
@property (nonatomic, readonly) float highFrequencyField;
@property (nonatomic, readonly) float meanLowFrequencyField;
@property (nonatomic, readonly) float meanHighFrequencyField;

- (BOOL)updateWithFieldType:(SFFieldType)fieldType;

// noize vector correction
- (void)enableFFTNoizeVectorCorrection;
- (void)disableFFTNoizeVectorCorrection;
- (void)resetFFTNoizeVectorCorrection;

@end
