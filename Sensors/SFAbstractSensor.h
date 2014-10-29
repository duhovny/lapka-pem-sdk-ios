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
extern NSString *const SFSensorDidUpdateMeanValue;
extern NSString *const SFSensorDidUpdateValue;


@interface SFAbstractSensor : NSObject <SFSignalProcessorDelegate>

@property (nonatomic, retain) SFSignalProcessor *signalProcessor;
@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;

- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor;

- (void)switchOn;
- (void)switchOff;

@end
