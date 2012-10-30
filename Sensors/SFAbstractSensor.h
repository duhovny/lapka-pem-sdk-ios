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


@class SFAbstractSensor;

@protocol SFAbstractSensorDelegate <NSObject>
@optional
- (void)sensorDidSwitchOn:(SFAbstractSensor *)sensor;
- (void)sensorDidSwitchOff:(SFAbstractSensor *)sensor;
@end

@interface SFAbstractSensor : NSObject <SFSignalProcessorDelegate>

@property (nonatomic, retain) SFSignalProcessor *signalProcessor;
@property (nonatomic, readonly, getter = isPluggedIn) BOOL pluggedIn;
@property (nonatomic, assign) NSObject <SFAbstractSensorDelegate> *delegate;

- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor;

- (void)switchOn;
- (void)switchOff;

@end
