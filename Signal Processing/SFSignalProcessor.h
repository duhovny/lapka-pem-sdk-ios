//
//  SenseFramework/SFSignalProcessor.h
//  Tailored at 2012 by Bowyer, all rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SFSignalFFTAnalyzer.h"
#import "SFSignalImpulseDetector.h"


typedef enum {
	SFSignalWaveTypeSin = 0,
	SFSignalWaveTypeSquare
} SFSignalWaveType;


@protocol SFSignalProcessorDelegate <NSObject>
@optional
// mean ampletude is average value of fft ampletudes during mean steps
- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude;
// max amplitude is maximum value of signal in single chunk of data
- (void)signalProcessorDidUpdateMaxAmplitude:(Float32)maxAmplitude;
// amplitude is fft amplitude for specified frequency in single chunk of data
- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude;
// called each time when impulse detected
// it happens when max amplitude of signal goes above threshold
- (void)signalProcessorDidRecognizeImpulse;
@end


@interface SFSignalProcessor : NSObject <SFSignalFFTAnalyzerDelegate, SFSignalImpulseDetectorDelegate> {
@public
	AudioComponentInstance audioUnit;
	double left_theta;
	double right_theta;
}

@property (nonatomic, assign) NSObject <SFSignalProcessorDelegate> *delegate;
@property (nonatomic, retain) SFSignalFFTAnalyzer *fftAnalyzer;
@property (nonatomic, retain) SFSignalImpulseDetector *impulseDetector;
@property (nonatomic, assign) BOOL antiphase;

// you can set frequency separately for each channel and analyzer
// or use setFrequency method to set all three to one value
@property (nonatomic, assign) double leftFrequency;
@property (nonatomic, assign) double rightFrequency;
@property (nonatomic, assign) double analyzerFrequency;

// you can set amplitude separately for each channel
// or use setAmplitude method to set both at once
@property (nonatomic, assign) double leftAmplitude;
@property (nonatomic, assign) double rightAmplitude;

@property (nonatomic, assign) SFSignalWaveType leftWaveType;
@property (nonatomic, assign) SFSignalWaveType rightWaveType;

@property (nonatomic, assign) double sampleRate;
@property (nonatomic, readonly) UInt32 numberOfFrames;

@property (nonatomic, assign) BOOL fftAnalyzerEnabled;
@property (nonatomic, assign) BOOL impulseDetectorEnabled;

// delayed amplitude updates
@property (nonatomic, assign) BOOL scheduledLeftAmplitudeUpdate;
@property (nonatomic, assign) BOOL scheduledRightAmplitudeUpdate;
@property (nonatomic, assign) double scheduledLeftAmplitudeValue;
@property (nonatomic, assign) double scheduledRightAmplitudeValue;
@property (nonatomic, assign) int scheduledLeftAmplitudeDelay;
@property (nonatomic, assign) int scheduledRightAmplitudeDelay;

- (BOOL)start;
- (void)stop;
- (void)reboot;

- (void)setFrequency:(double)value;
- (void)setAmplitude:(double)value;
- (void)setWaveType:(SFSignalWaveType)value;

- (void)setLeftAmplitude:(double)value afterDelay:(NSTimeInterval)delay;
- (void)setRightAmplitude:(double)value afterDelay:(NSTimeInterval)delay;

- (double)optimizeFrequency:(double)frequency;

@end
