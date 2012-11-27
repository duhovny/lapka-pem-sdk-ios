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
#define kSFFieldSensorDualModeMeanSteps 4		// 80ms (60ms delay + 20ms measure)
#define kSFFieldSensorSingleModeMeanSteps 25
#define kSFFieldSensorDefaultSmallestMaxForHighFrequencyField 150.0

#define kSF_PositiveLFFieldThreshold 0.0100

#define kSFFieldSensorOutputHighFrequencyScale_iPhone5 4.8


@interface SFFieldSensor () {
	int _stepsToSkip;
	float _smallestHighFrequencyAmplitude;
	
	// FFT Sign (for LF field only)
	BOOL _fftSignEnabled;
	BOOL _fftSignVerified;
	float _fftLFFieldAngle;
	
	// FFT Zero Shift (for LF field only)
	BOOL _fftZeroShiftEnabled;
	float _fftLFFieldReal;
	float _fftLFFieldImag;
	
	// platform depended coefs
	float _outputHighFrequencyScale;
}

- (Float32)verifyFFTSignWithAmplitude:(Float32)amplitude;

@end


@implementation SFFieldSensor

@synthesize pluggedIn;
@synthesize lowFrequencyField;
@synthesize highFrequencyField;
@synthesize meanLowFrequencyField;
@synthesize meanHighFrequencyField;
@synthesize measureLowFrequencyField;
@synthesize measureHighFrequencyField;
@synthesize state;
@synthesize isOn;
@dynamic delegate;




#pragma mark -
#pragma mark Lifecycle


- (id)initWithSignalProcessor:(SFSignalProcessor *)aSignalProcessor {
	
	if ((self = [super initWithSignalProcessor:aSignalProcessor]))
	{
		// default values
		self.measureLowFrequencyField = YES;
		self.measureHighFrequencyField = YES;
		
		_stepsToSkip = 0;
		_smallestHighFrequencyAmplitude = kSFFieldSensorDefaultSmallestMaxForHighFrequencyField;
		_outputHighFrequencyScale = 1.0;
		
		SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
		if (hardwarePlatform == SFDeviceHardwarePlatform_iPhone_5) {
			NSLog(@"SFDeviceHardwarePlatform_iPhone_5");
			_outputHighFrequencyScale = kSFFieldSensorOutputHighFrequencyScale_iPhone5;
		}
	}
	return self;
}




#pragma mark -
#pragma mark ON/OFF


- (void)switchOn {
	
	if (![self isPluggedIn]) {
		NSLog(@"SFieldSensor is not plugged in. Not able to switch on.");
		return;
	}
	
	if ([self isOn]) {
		NSLog(@"SFieldSensor is already on.");
		return;
	}
	
	// set volume up
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
	
	// setup signal processor according to state
	self.signalProcessor.frequency = [self.signalProcessor optimizeFrequency:kSFFieldSensorFrequency];
	if (self.dualMode) {
		NSLog(@"SFieldSensor: dual mode");
		self.signalProcessor.fftAnalyzer.meanSteps = kSFFieldSensorDualModeMeanSteps;
		[self setupSignalProcessorForLowFrequencyMeasure];
		state = kSFFieldSensorStateLowFrequencyMeasurement;
	} else {
		self.signalProcessor.fftAnalyzer.meanSteps = kSFFieldSensorSingleModeMeanSteps;
		if (measureLowFrequencyField) {
			NSLog(@"SFieldSensor: single mode: low frequency");
			[self setupSignalProcessorForLowFrequencyMeasure];
			state = kSFFieldSensorStateLowFrequencyMeasurement;
		} else if (measureHighFrequencyField) {
			NSLog(@"SFieldSensor: single mode: high frequency");
			_stepsToSkip = 1;
			[self setupSignalProcessorForHighFrequencyMeasure];
			state = kSFFieldSensorStateHighFrequencyMeasurement;
		}
	}
	
	[self.signalProcessor start];
	isOn = YES;
	
	[super switchOn];
}


- (void)switchOff {
	
	[self.signalProcessor stop];
	state = kSFFieldSensorStateOff;
	isOn = NO;
	lowFrequencyField = 0;
	highFrequencyField = 0;
	
	_fftSignEnabled = NO;
	_fftSignVerified = NO;
	
	_fftZeroShiftEnabled = NO;
	
	[super switchOff];
}




#pragma mark -
#pragma mark Signal Processor setup


- (void)setupSignalProcessorForLowFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.useSign = _fftSignEnabled;
	self.signalProcessor.fftAnalyzer.useZeroShift = _fftZeroShiftEnabled;
}


- (void)setupSignalProcessorForHighFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.useSign = NO;
	self.signalProcessor.fftAnalyzer.useZeroShift = NO;
}




#pragma mark -
#pragma mark FFT Sign


- (void)enableFFTZeroShiftForLowFrequencyField {
	
	self.signalProcessor.fftAnalyzer.realShift -= _fftLFFieldReal;
	self.signalProcessor.fftAnalyzer.imagShift -= _fftLFFieldImag;
	
	_fftZeroShiftEnabled = YES;
	
	if (state == kSFFieldSensorStateLowFrequencyMeasurement) {
		self.signalProcessor.fftAnalyzer.useZeroShift = _fftZeroShiftEnabled;
	}
}


- (void)enableFFTSignForLowFrequencyField {
	
	if (_fftSignEnabled) return;
	_fftSignEnabled = YES;
	
	[self.signalProcessor.fftAnalyzer setAngleShift:-_fftLFFieldAngle];
}


- (Float32)verifyFFTSignWithAmplitude:(Float32)amplitude {
	
	if (!_fftSignEnabled) return amplitude;
	if (_fftSignVerified) return amplitude;
	
	if (ABS(amplitude) > kSF_PositiveLFFieldThreshold) {
		// correct angle shift
		float currentAngle = self.signalProcessor.fftAnalyzer.angle - self.signalProcessor.fftAnalyzer.angleShift;
		float oppositeAngle = (currentAngle < 0) ? currentAngle + 180 : currentAngle - 180;
		[self.signalProcessor.fftAnalyzer setAngleShift:-oppositeAngle];
		
		if (amplitude < 0)
			amplitude = -amplitude;
		
		_fftSignVerified = YES;
	}
	
	return amplitude;
}




#pragma mark -
#pragma mark Calculations


- (float)calculateLowFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude;
	return value;
}


- (float)calculateHighFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude - _smallestHighFrequencyAmplitude;
	value *= _outputHighFrequencyScale;
	return MAX(value, 0);
}




#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	
	if (_stepsToSkip > 0) return;
	if (self.dualMode) return;
	
	// single mode
	switch (state) {
			
		case kSFFieldSensorStateOff:
			break;
			
		case kSFFieldSensorStateLowFrequencyMeasurement:
		{
			_fftLFFieldReal = self.signalProcessor.fftAnalyzer.real;
			_fftLFFieldImag = self.signalProcessor.fftAnalyzer.imag;
			_fftLFFieldAngle = self.signalProcessor.fftAnalyzer.angle;
			if (!_fftSignVerified)
				amplitude = [self verifyFFTSignWithAmplitude:amplitude];
			lowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateLowFrequencyField:lowFrequencyField];
			break;
		}
			
		case kSFFieldSensorStateHighFrequencyMeasurement:
		{
			highFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateHighFrequencyField:highFrequencyField];
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
		
	if (_stepsToSkip > 0) {
		_stepsToSkip--;
		return;
	}
	
	if (self.dualMode) {
		
		switch (state) {
				
			case kSFFieldSensorStateOff:
				NSLog(@"Warning: SFieldSensor get measure result when off.");
				break;
				
			case kSFFieldSensorStateLowFrequencyMeasurement:
			{
				// last (not mean) amplitude value
				float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
				_fftLFFieldReal = self.signalProcessor.fftAnalyzer.real;
				_fftLFFieldImag = self.signalProcessor.fftAnalyzer.imag;
				_fftLFFieldAngle = self.signalProcessor.fftAnalyzer.angle;
				if (!_fftSignVerified)
					amplitude = [self verifyFFTSignWithAmplitude:amplitude];
				lowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:amplitude];
				meanLowFrequencyField = lowFrequencyField;
				
				[self.delegate fieldSensorDidUpdateLowFrequencyField:lowFrequencyField];
				[self.delegate fieldSensorDidUpdateMeanLowFrequencyField:meanLowFrequencyField];
				
				// switch signal processor to high frequency
				[self setupSignalProcessorForHighFrequencyMeasure];
				state = kSFFieldSensorStateHighFrequencyMeasurement;
				break;
			}
				
			case kSFFieldSensorStateHighFrequencyMeasurement:
			{
				// last (not mean) amplitude value
				float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
				if (amplitude < _smallestHighFrequencyAmplitude)
					_smallestHighFrequencyAmplitude = amplitude;
				highFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:amplitude];
				meanHighFrequencyField = highFrequencyField;
				
				[self.delegate fieldSensorDidUpdateHighFrequencyField:highFrequencyField];
				[self.delegate fieldSensorDidUpdateMeanHighFrequencyField:meanHighFrequencyField];
				
				// switch signal processor to low frequency
				[self setupSignalProcessorForLowFrequencyMeasure];
				state = kSFFieldSensorStateLowFrequencyMeasurement;
				break;
			}
				
			default:
				break;
		}
		
	} else { // single mode
		
		switch (state) {
				
			case kSFFieldSensorStateOff:
				NSLog(@"Warning: SFieldSensor get measure result when off.");
				break;
				
			case kSFFieldSensorStateLowFrequencyMeasurement:
			{
				meanLowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:meanAmplitude];
				[self.delegate fieldSensorDidUpdateMeanLowFrequencyField:meanLowFrequencyField];
				break;
			}
				
			case kSFFieldSensorStateHighFrequencyMeasurement:
			{
				if (meanAmplitude < _smallestHighFrequencyAmplitude)
					_smallestHighFrequencyAmplitude = meanAmplitude;
				meanHighFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:meanAmplitude];
				[self.delegate fieldSensorDidUpdateMeanHighFrequencyField:meanHighFrequencyField];
				break;
			}
				
			default:
				break;
		}
	}
}




#pragma mark -
#pragma mark Avaliability


- (BOOL)isPluggedIn {
	// refactor: this is not taking sensor type in account
	return [[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut];
}




#pragma mark -
#pragma mark Setters


- (void)setMeasureLowFrequencyField:(BOOL)value {
	
	measureLowFrequencyField = value;
	
	// switch high ON if you switching low OFF
	if (!measureLowFrequencyField && !measureHighFrequencyField)
		measureHighFrequencyField = YES;
}


- (void)setMeasureHighFrequencyField:(BOOL)value {
	
	measureHighFrequencyField = value;
	
	// switch low ON if you switching high OFF
	if (!measureHighFrequencyField && !measureLowFrequencyField)
		measureLowFrequencyField = YES;
}


- (BOOL)dualMode {
	BOOL isDualMode = (measureLowFrequencyField && measureHighFrequencyField);
	return isDualMode;
}




@end
