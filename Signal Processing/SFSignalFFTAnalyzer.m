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
		_useNoizeVectorCorrection = NO;
		_realNoize = 0;
		_imagNoize = 0;
		_realSignalMax = 0;
		_imagSignalMax = 0;
		
		// Set the size of FFT.
		n = numberOfFrames;
		log2n = log2(n);
		stride = 1;
		nOver2 = n / 2;
		
		// Allocate memory for the input operands and check its availability,
		// use the vector version to get 16-byte alignment.
		fft_complex_split.realp = (Float32 *) malloc(nOver2 * sizeof(Float32));
		fft_complex_split.imagp = (Float32 *) malloc(nOver2 * sizeof(Float32));
		
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
	
	/* Find amplitude by frequency */
	
	UInt32 required_bin = frequency * n / sampleRate;
	
	/* FFT Parts */
	
	_real = fft_complex_split.realp[required_bin];
	_imag = fft_complex_split.imagp[required_bin];
	
	/* Angle */
	float angleInRadians = atan2f(_real,_imag);
	_angle = angleInRadians / M_PI * 180;
	
	
	if (_useNoizeVectorCorrection) {
		
		// Initialize extreme vectors
		BOOL noizeAndSignalMaxVectorsAreNotInitialized = (_realNoize == 0) && (_imagNoize == 0) && (_realSignalMax == 0) && (_imagSignalMax == 0);
		if (noizeAndSignalMaxVectorsAreNotInitialized) {
			_realNoize = _real;
			_imagNoize = _imag;
			_realSignalMax = _real;
			_imagSignalMax = _imag;
		}
		
		// calc distances
		float signalToNoizeDistance = sqrtf(powf((_real - _realNoize), 2) + powf((_imag - _imagNoize), 2));
		float signalToMaxDistance = sqrtf(powf((_real - _realSignalMax), 2) + powf((_imag - _imagSignalMax), 2));
		float noizeToMaxDistance = sqrtf(powf((_realNoize - _realSignalMax), 2) + powf((_imagNoize - _imagSignalMax), 2));
		
		// update extreme vectors
		if (signalToNoizeDistance > noizeToMaxDistance) {
			_realSignalMax = _real;
			_imagSignalMax = _imag;
		} else if (signalToMaxDistance > noizeToMaxDistance) {
			float zeroToMaxDistance = sqrtf(powf((_realSignalMax), 2) + powf((_imagSignalMax), 2));
			float zeroToSignalDistance = sqrtf(powf((_real), 2) + powf((_imag), 2));
			if (zeroToMaxDistance > zeroToSignalDistance) {
				_realNoize = _real;
				_imagNoize = _imag;
			} else {
				_realNoize = _realSignalMax;
				_imagNoize = _imagSignalMax;
				_realSignalMax = _real;
				_imagSignalMax = _imag;
			}
		}
		
		float noizeToSignalDistance = sqrtf(powf((_realNoize - _real), 2) + powf((_imagNoize - _imag), 2));
		amplitude = noizeToSignalDistance;
		
	} else {
		amplitude = sqrtf(_real * _real + _imag * _imag);
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
