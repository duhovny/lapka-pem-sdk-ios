//
//	SenseFramework/SFFieldSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFFieldSensor.h"
#import "SFAudioSessionManager.h"
#import "SFSignalProcessor.h"
#import "SFIdentificator.h"
#import "SFSensorManager.h"

#define kSFFieldSensorFrequency 16000
#define kSFFieldSensorMeanSteps 25


#define kSFFieldSensorScaleCoef_Default		1.0
#define kSFFieldSensorScaleCoef_iPhone4		1.0
#define kSFFieldSensorScaleCoef_iPhone4S	0.8
#define kSFFieldSensorScaleCoef_iPhone5		2.5
#define kSFFieldSensorScaleCoef_iPad4		0.8
#define kSFFieldSensorScaleCoef_iPadMini	0.8
#define kSFFieldSensorScaleCoef_iPod4		1.6


#define kSFFieldSensorHF_K1 30.0
#define kSFFieldSensorHF_K2  4.5

#define kSFFieldSensorLF_K1  10.0
#define kSFFieldSensorLF_K2 320.0

#define kSF_PositiveLFFieldThreshold 0.0100

#define kSFFieldSensorCalibrationTime 40.0

#define RANDOM_0_1() ((random() / (float)0x7fffffff))


@interface SFAbstractSensor ()
- (void)calibrationComplete;
@end


@interface SFFieldSensor () {
	BOOL _fftNoizeVectorCorrectionEnabled;
}
@property (nonatomic, strong) NSTimer *calibrationTimer;
@property (nonatomic, strong) NSTimer *simulateValueTimer;
@property (nonatomic, strong) NSTimer *simulateMeanValueTimer;
@end


@implementation SFFieldSensor


#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		// default values
		_fieldType = SFFieldTypeHighFrequency;
		_state = SFFieldSensorStateOff;
		
		self.hf_K1 = kSFFieldSensorHF_K1;
		self.hf_K2 = kSFFieldSensorHF_K2;
		self.lf_K1 = kSFFieldSensorLF_K1;
		self.lf_K2 = kSFFieldSensorLF_K2;
		
		
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		_scaleCoef = [self scaleCoefficientForHardwarePlatform:hardwarePlatform];
		
	}
	return self;
}


- (void)dealloc {
	
	[self.calibrationTimer invalidate];
	self.calibrationTimer = nil;
	
	[_simulateMeanValueTimer invalidate];
	self.simulateMeanValueTimer = nil;
	
	[_simulateValueTimer invalidate];
	self.simulateValueTimer = nil;
	
	[self.signalProcessor stop];
}




#pragma mark -
#pragma mark Field Type


- (BOOL)updateWithFieldType:(SFFieldType)fieldType {
	
	if (_state == SFFieldSensorStateOff ||
		_state == SFFieldSensorStateReady)
	{
		_fieldType = fieldType;
		[self setupSignalProcessorForFieldType:_fieldType];
		return YES;
	}
	return NO;
}




#pragma mark -
#pragma mark Calibration


- (void)startCalibration {
	
	if (![self isPluggedIn]) {
		
		BOOL iamSimulated = [[SFSensorManager sharedManager] isSensorSimulated];
		if (iamSimulated) {
			
			_state = SFFieldSensorStateCalibrating;
			self.simulateValueTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(simulateDidUpdateValue) userInfo:nil repeats:YES];
			self.simulateMeanValueTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(simulateDidUpdateMeanValue) userInfo:nil repeats:YES];
			self.calibrationTimer = [NSTimer scheduledTimerWithTimeInterval:self.calibrationTime target:self selector:@selector(calibrationComplete) userInfo:nil repeats:NO];
			[super startCalibration];
			return;
		}
		
		NSLog(@"SFieldSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	[self setOutputVolumeUp];
	[self setupSignalProcessorForFieldType:_fieldType];
	
	[self.signalProcessor start];
	_state = SFFieldSensorStateCalibrating;
	
	self.calibrationTimer = [NSTimer scheduledTimerWithTimeInterval:self.calibrationTime target:self selector:@selector(calibrationComplete) userInfo:nil repeats:NO];
	[super startCalibration];
}


- (void)calibrationComplete {
	
	_state = SFFieldSensorStateReady;
	[super calibrationComplete];
}


- (NSTimeInterval)calibrationTime {
	return kSFFieldSensorCalibrationTime;
}


#pragma mark -
#pragma mark Measure


- (void)startMeasure {
	
	if (![self isPluggedIn]) {
		
		BOOL iamSimulated = [[SFSensorManager sharedManager] isSensorSimulated];
		if (iamSimulated) {
			
			[super startMeasure];
			_state = SFFieldSensorStateMeasuring;
			return;
		}
		
		NSLog(@"SFieldSensor is not plugged in. Not able to start measure.");
		return;
	}
	
	[super startMeasure];
	
	[self enableFFTNoizeVectorCorrection];
	[self resetFFTNoizeVectorCorrection];
	
	_state = SFFieldSensorStateMeasuring;
}


- (void)stopMeasure {
	
	_state = SFFieldSensorStateReady;
	
	_lowFrequencyField = 0;
	_highFrequencyField = 0;
	
	[super stopMeasure];
}




#pragma mark -
#pragma mark Signal Processor setup


- (void)setupSignalProcessorForFieldType:(SFFieldType)fieldType {
	
	self.signalProcessor.frequency = [self.signalProcessor optimizeFrequency:kSFFieldSensorFrequency];
	self.signalProcessor.fftAnalyzer.meanSteps = kSFFieldSensorMeanSteps;
	if (_fieldType == SFFieldTypeLowFrequency) {
		self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
		self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	} else {
		self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
		self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	}
}


#pragma mark -
#pragma mark FFT Noize Vector Correction


- (void)enableFFTNoizeVectorCorrection {
	
	_fftNoizeVectorCorrectionEnabled = YES;
	self.signalProcessor.fftAnalyzer.useNoizeVectorCorrection = YES;
}


- (void)disableFFTNoizeVectorCorrection {
	
	_fftNoizeVectorCorrectionEnabled = NO;
	self.signalProcessor.fftAnalyzer.useNoizeVectorCorrection = NO;
}


- (void)resetFFTNoizeVectorCorrection {
	
	self.signalProcessor.fftAnalyzer.realSignalMax = 0;
	self.signalProcessor.fftAnalyzer.imagSignalMax = 0;
	self.signalProcessor.fftAnalyzer.realNoize = 0;
	self.signalProcessor.fftAnalyzer.imagNoize = 0;
	self.signalProcessor.fftAnalyzer.realZero = 0;
	self.signalProcessor.fftAnalyzer.imagZero = 0;
}




#pragma mark -
#pragma mark Calculations


- (float)calculateLowFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude * _scaleCoef;
	
	float K1 = _lf_K1;
	float K2 = _lf_K2;
	
	float U = (exp(K1 * value) - 1) * K2;
	
	return MAX(U, 0);
}


- (float)calculateHighFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude * _scaleCoef;
	
	float K1 = _hf_K1;
	float K2 = _hf_K2;
	
	float U = (exp(K1 * value) - 1) * K2;
	
	return MAX(U, 0);
}




#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	
	if (_state != SFFieldSensorStateMeasuring) return;
	
	switch (_fieldType) {
			
		case SFFieldTypeLowFrequency:
		{
			_lowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:amplitude];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@(_lowFrequencyField)];
			});
			break;
		}
			
		case SFFieldTypeHighFrequency:
		{
			_highFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:amplitude];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@(_highFrequencyField)];
			});
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
		
	if (_state != SFFieldSensorStateMeasuring) return;
		
	switch (_fieldType) {
			
		case SFFieldTypeLowFrequency:
		{
			_meanLowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:meanAmplitude];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateMeanValue object:@(_meanLowFrequencyField)];
			});
			break;
		}
			
		case SFFieldTypeHighFrequency:
		{
			_meanHighFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:meanAmplitude];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateMeanValue object:@(_meanHighFrequencyField)];
			});
			break;
		}
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark Utilities


- (void)setOutputVolumeUp {
	
	float outputVolume;
	id field_volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"field_volume"];
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (field_volume) {
		NSLog(@"SFFieldSensor: set specific field volume");
		outputVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"field_volume"];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	} else if (european_preference) {
		NSLog(@"SFFieldSensor: set current region volume");
		outputVolume = [[SFAudioSessionManager sharedManager] currentRegionMaxVolume];
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
	}
}


- (float)scaleCoefficientForHardwarePlatform:(SFDeviceHardwarePlatform)hardwarePlatform {
	
	float scaleCoefficient;
	
	switch (hardwarePlatform) {
			
		case SFDeviceHardwarePlatform_iPhone_3GS:
		case SFDeviceHardwarePlatform_iPhone_4:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPhone4;
			break;
		}
			
		case SFDeviceHardwarePlatform_iPhone_4S:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPhone4S;
			break;
		}
			
		case SFDeviceHardwarePlatform_iPhone_5:
		case SFDeviceHardwarePlatform_iPod_Touch_5G:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPhone5;
			break;
		}
			
		case SFDeviceHardwarePlatform_iPod_Touch_4G:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPod4;
			break;
		}
			
		case SFDeviceHardwarePlatform_iPad_2:
		case SFDeviceHardwarePlatform_iPad_3:
		case SFDeviceHardwarePlatform_iPad_4:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPad4;
			break;
		}
			
		case SFDeviceHardwarePlatform_iPad_Mini:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_iPadMini;
			break;
		}
			
		default:
		{
			scaleCoefficient = kSFFieldSensorScaleCoef_Default;
			break;
		}
	}
	return scaleCoefficient;
}


#pragma mark -
#pragma mark Simulation


- (void)simulateDidUpdateValue {
	
	if (_state != SFFieldSensorStateMeasuring) return;
	
	float value = 1.2 + 2.0 * RANDOM_0_1();
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateValue object:@(value)];
	});
}


- (void)simulateDidUpdateMeanValue {
	
	if (_state != SFFieldSensorStateMeasuring) return;
	
	float value = 1.2 + 2.0 * RANDOM_0_1();
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:SFSensorDidUpdateMeanValue object:@(value)];
	});
}


@end
