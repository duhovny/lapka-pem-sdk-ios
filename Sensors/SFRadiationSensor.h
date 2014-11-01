//
//	SenseFramework/SFRadiationSensor.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFAbstractSensor.h"


@interface SFRadiationSensor : SFAbstractSensor

@property (nonatomic, readonly) float time;
@property (nonatomic, readonly) float particles;
@property (nonatomic, readonly) double particlesPerMinute;
@property (nonatomic, readonly) double radiationLevel;

- (float)convertParticlesPerMinutesToMicrosievertsPerHour:(float)ppm;
- (float)convertParticlesPerMinutesToMicrorentgensPerHour:(float)ppm;

@end
