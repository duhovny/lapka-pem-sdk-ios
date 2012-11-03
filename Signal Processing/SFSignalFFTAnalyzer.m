//
//  SenseFramework/SFSignalFFTAnalyzer.m
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFSignalFFTAnalyzer.h"

@implementation SFSignalFFTAnalyzer

@synthesize delegate;
@synthesize frequency;
@synthesize sampleRate;
@synthesize amplitude;
@synthesize meanAmplitude;
@synthesize meanSteps;


#pragma mark -
#pragma mark Lifecycle


- (id)initWithNumberOfFrames:(UInt32)numberOfFrames {
	if ((self = [super init])) {
		
		// Default
		_useSign = NO;
		
		// Set the size of FFT.
		n = numberOfFrames;
		log2n = log2(n);
		stride = 1;
		nOver2 = n / 2;
		
		// Allocate memory for the input operands and check its availability,
		// use the vector version to get 16-byte alignment.
		fft_complex_split.realp = (Float32 *) malloc(nOver2 * sizeof(Float32));
		fft_complex_split.imagp = (Float32 *) malloc(nOver2 * sizeof(Float32));
		obtainedReal = (Float32 *) malloc(n * sizeof(Float32));
		obtained_int = (int32_t *) malloc(n * sizeof(int32_t));
		
		if (fft_complex_split.realp == NULL || fft_complex_split.imagp == NULL) {
			printf("SSignalFFTAnalyzer: malloc failed to allocate memory for the real FFT section of the sample.\n");
		}
		
		// Set up the required memory for the FFT routines and check its availability.
		fft_setup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
		if (fft_setup == NULL) {
			printf("SSignalFFTAnalyzer: FFT_Setup failed to allocate enough memory for the real FFT.\n");
		}
	}
	return self;
}

- (void)dealloc {
	
	/* Free the allocated memory. */
	
    vDSP_destroy_fftsetup(fft_setup);
    free(obtainedReal);
    free(fft_complex_split.realp);
    free(fft_complex_split.imagp);
}


#pragma mark -
#pragma mark Proccess FFT


- (void)processFFTWithData:(Float32 *)data {
	
	/* Look at the real signal as an interleaved complex vector by
     * casting it. Then call the transformation function vDSP_ctoz to
     * get a split complex vector, which for a real signal, divides into
     * an even-odd configuration. */
	
    vDSP_ctoz((COMPLEX *)data, 2, &fft_complex_split, 1, nOver2);
	
	/* Carry out a Forward FFT transform. */
	
    vDSP_fft_zrip(fft_setup, &fft_complex_split, stride, log2n, FFT_FORWARD);
	
	/* Verify correctness of the results, but first scale it by  2n. */
	
    scale = (Float32) 1.0 / (2 * n);
    vDSP_vsmul(fft_complex_split.realp, 1, &scale, fft_complex_split.realp, 1, nOver2);
    vDSP_vsmul(fft_complex_split.imagp, 1, &scale, fft_complex_split.imagp, 1, nOver2);
	
	/* The output signal is now in a split real form. Use the function
     * vDSP_ztoc to get a split real vector. */
	
    vDSP_ztoc(&fft_complex_split, 1, (COMPLEX *)obtainedReal, 2, nOver2);
	
	/* Find amplitude by frequency */
	
	UInt32 required_bin = frequency * n / sampleRate;
	
	/* Sign */
	
	double requiredReal = fft_complex_split.realp[required_bin];
	double requiredImag = fft_complex_split.imagp[required_bin];
	
//	double requiredMax = requiredReal;
//	int sign = _useSign ? 2*signbit(requiredMax) - 1 : 1;
	
	if (_useSign) {
		float angleRad = atan2f(requiredReal,requiredImag);
		float angle = angleRad / M_PI * 180;
		int sign = 1 - 2*signbit(angle);
		NSLog(@"ang: %0.1f", angle);
		amplitude = sign * sqrtf(requiredReal * requiredReal + requiredImag * requiredImag);
	} else {
		amplitude = sqrtf(requiredReal * requiredReal + requiredImag * requiredImag);
	}
	
	[delegate fftAnalyzerDidUpdateAmplitude:amplitude];
	
	/* update statistic */
	
	sumOfAmplitudes += amplitude;
	meanStep++;
	if (meanStep >= meanSteps) {
		meanAmplitude = sumOfAmplitudes / meanSteps;
		meanStep = 0;
		sumOfAmplitudes = 0;
		[delegate fftAnalyzerDidUpdateMeanAmplitude:meanAmplitude];
	}
}

@end
