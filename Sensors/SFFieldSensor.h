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

@protocol SFFieldSensorDelegate <SFAbstractSensorDelegate>
- (void)fieldSensorDidUpdateLowFrequencyField:(float)field;
- (void)fieldSensorDidUpdateHighFrequencyField:(float)field;
- (void)fieldSensorDidUpdateMeanLowFrequencyField:(float)meanField;
- (void)fieldSensorDidUpdateMeanHighFrequencyField:(float)meanField;
@end


@interface SFFieldSensor : SFAbstractSensor

@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, readonly) BOOL isOn;
@property (nonatomic, assign) NSObject <SFFieldSensorDelegate> *delegate;
@property (nonatomic, readonly) SFFieldSensorState state;
@property (nonatomic, assign) BOOL measureLowFrequencyField;
@property (nonatomic, assign) BOOL measureHighFrequencyField;
@property (nonatomic, readonly) BOOL dualMode;
@property (nonatomic, readonly) float smallestHighFrequencyAmplitude;

@property (nonatomic, assign) float hfScale;
@property (nonatomic, assign) float hfUp;
@property (nonatomic, assign) float hfK1;
@property (nonatomic, assign) float hfK2;

// measures
@property (nonatomic, readonly) float lowFrequencyField;
@property (nonatomic, readonly) float highFrequencyField;
@property (nonatomic, readonly) float meanLowFrequencyField;
@property (nonatomic, readonly) float meanHighFrequencyField;

// noize vector correction
- (void)enableFFTNoizeVectorCorrection;
- (void)disableFFTNoizeVectorCorrection;
- (void)resetFFTNoizeVectorCorrection;

- (void)enableFFTZeroShiftForLowFrequencyField;

@end
