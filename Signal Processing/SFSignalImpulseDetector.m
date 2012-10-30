//
//  SenseFramework/SFSignalImpulseDetector.m
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFSignalImpulseDetector.h"

#define kSFSignalImpulseDetectorDefaultThreshold 0.025

@implementation SFSignalImpulseDetector
@synthesize delegate;
@synthesize threshold;
@synthesize previousValueWasAboveThreshold;

- (id)initWithNumberOfFrames:(UInt32)numberOfFrames {
	if ((self = [super init])) {
		
		// Set the size of FFT.
		n = numberOfFrames;
		
		self.threshold = kSFSignalImpulseDetectorDefaultThreshold;
	}
	return self;
}


- (void)dealloc {
}


#pragma mark -
#pragma mark Proccess Impulse Detection


- (void)processImpulseDetectionWithData:(Float32 *)data {

	vDSP_Stride stride = 1;
	Float32 max;
	
	// calculate maximum value of vector
	// that is maximum amplitude of signal
	vDSP_maxv(data, stride, &max, n);
	
	[delegate impulseDetectorDidUpdateMaxAmplitude:max];
	
	BOOL isAboveThreshold = (max > self.threshold);
	if (isAboveThreshold && !previousValueWasAboveThreshold) {
		// we got impulse here
		[delegate impulseDetectorDidDetectImpulse];
	}
	previousValueWasAboveThreshold = isAboveThreshold;
	
	
	// log raw data
	
	/*
	printf("processImpulseDetectionWithData:\n");
	
	int i;
	for (i=0; i<n; i++) {
		Float32 bit = data[i];
		printf("%f\n", bit);
	}
	*/
}

@end
