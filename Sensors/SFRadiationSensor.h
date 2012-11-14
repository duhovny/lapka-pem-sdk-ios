//
//	SenseFramework/SFRadiationSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFAbstractSensor.h"


typedef enum {
	kSFRadiationSensorStateOff = 0,
	kSFRadiationSensorStateOn
} SFRadiationSensorState;

@protocol SFRadiationSensorDelegate <SFAbstractSensorDelegate>
- (void)radiationSensorDidUpdateRadiation:(float)radiation;
@optional
- (void)radiationSensorDidUpdateMaxSignalAmplitude:(float)maxAmplitude;
- (void)radiationSensorDidUpdateImpulseTreshold:(float)impulseThreshold;
- (void)radiationSensorDidRecognizeImpulse:(float)impulseAmplitude;
- (void)radiationSensorDidReceiveParticle;
@end


@interface SFRadiationSensor : SFAbstractSensor

// refactor: #senseframework move isOn to abstract sensor class
@property (nonatomic, readonly) BOOL isOn;
@property (nonatomic, assign) NSObject <SFRadiationSensorDelegate> *delegate;
@property (nonatomic, readonly) SFRadiationSensorState state;

@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, assign) float time;
@property (nonatomic, assign) float particles;
@property (nonatomic, assign) float impulseThreshold;
@property (nonatomic, readonly) double particlesPerMinute;
@property (nonatomic, readonly) double radiationLevel;
// use Rentgen if NO
@property (nonatomic, assign) BOOL useSievert;

- (void)reset;

- (float)convertParticlesPerMinutesToMicrosievertsPerHour:(float)ppm;
- (float)convertParticlesPerMinutesToMicrorentgensPerHour:(float)ppm;

@end
