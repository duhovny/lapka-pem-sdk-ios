//
//  SenseFramework/SFSignalImpulseDetector.h
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@protocol SFSignalImpulseDetectorDelegate <NSObject>
- (void)impulseDetectorDidDetectImpulse;
- (void)impulseDetectorDidUpdateMaxAmplitude:(Float32)maxAmplitude;
@end

@interface SFSignalImpulseDetector : NSObject {
	
	uint32_t n;
}

@property (nonatomic, assign) NSObject <SFSignalImpulseDetectorDelegate> *delegate;
@property (nonatomic, assign) float threshold;
@property (nonatomic, assign) float impulseAmplitude;
@property (nonatomic, assign) BOOL previousValueWasAboveThreshold;

- (id)initWithNumberOfFrames:(UInt32)numberOfFrames;
- (void)processImpulseDetectionWithData:(Float32 *)data;

@end
