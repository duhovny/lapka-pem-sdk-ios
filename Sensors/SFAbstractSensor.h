//
//	SenseFramework/SFAbstractSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//
//	Abstract Sensor describe all functionality
//	common for Lapka sensors.
//

#import <UIKit/UIKit.h>
#import "SFSignalProcessor.h"

#define kSFControlSignalBitZero	0.0
#define kSFControlSignalBitOne	1.0

extern NSString *const SFSensorWillStartCalibration;
extern NSString *const SFSensorDidCompleteCalibration;
extern NSString *const SFSensorDidCancelCalibration;
extern NSString *const SFSensorWillStartMeasure;
extern NSString *const SFSensorDidCompleteMeasure;
extern NSString *const SFSensorDidUpdateValue;
extern NSString *const SFSensorDidUpdateIntermediateValue;

typedef enum {
	SFSensorStateOff,
	SFSensorStateCalibrating,
	SFSensorStateReady,
	SFSensorStateMeasuring
} SFSensorState;


@interface SFAbstractSensor : NSObject <SFSignalProcessorDelegate>

@property (nonatomic, strong) SFSignalProcessor *signalProcessor;
@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, readonly) NSTimeInterval calibrationTime;
@property (nonatomic, readonly, getter=isCalibrated) BOOL calibrated;
@property (nonatomic, readonly, getter=isMeasuring) BOOL measuring;
@property (nonatomic, readonly) SFSensorState sensorState;

- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor;

- (void)startCalibration;
- (void)cancelCalibration;
- (void)resetCalibration;
- (void)startMeasure;
- (void)stopMeasure;

@end
