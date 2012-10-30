//
//  SenseFramework/SFSignalFFTAnalyzer.h
//  Tailored at 2012 by Bowyer, all rights reserved.
//	

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>


@protocol SFSignalFFTAnalyzerDelegate <NSObject>
- (void)fftAnalyzerDidUpdateMeanAmplitude:(Float32)meanAmplitude;
- (void)fftAnalyzerDidUpdateAmplitude:(Float32)amplitude;
@end


@interface SFSignalFFTAnalyzer : NSObject {
	
	COMPLEX_SPLIT   fft_complex_split;
    FFTSetup        fft_setup;
    uint32_t        log2n;
    uint32_t        n, nOver2;
    int32_t         stride;
    Float32        *obtainedReal;
	int32_t        *obtained_int;
    Float32         scale;
	
	double sumOfAmplitudes;
	int meanStep;
}

@property (nonatomic, assign) NSObject <SFSignalFFTAnalyzerDelegate> *delegate;
@property (nonatomic, assign) double frequency;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, readonly) Float32 amplitude;
@property (nonatomic, readonly) Float32 meanAmplitude;
@property (nonatomic, assign) int meanSteps;

// refactor: this is so chip, please, analyze DC and do right math in near future, OK?
@property (nonatomic, assign) BOOL useSign;

- (id)initWithNumberOfFrames:(UInt32)numberOfFrames;
- (void)processFFTWithData:(Float32 *)data;

@end
