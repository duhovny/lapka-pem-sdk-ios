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

#define kSFFieldSensorDefaultHFScaleCoef 1.0
#define kSFFieldSensorDefaultHFUpCoef 0.0550
#define kSFFieldSensorDefaultHFK1Coef 130.0
#define kSFFieldSensorDefaultHFK2Coef 230.0

#define kSF_PositiveLFFieldThreshold 0.0100


@interface SFFieldSensor () {
	int _stepsToSkip;
	BOOL _fftNoizeVectorCorrectionEnabled;
}

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
		self.measureLowFrequencyField = NO;
		self.measureHighFrequencyField = YES;
		
		_stepsToSkip = 0;
		_smallestHighFrequencyAmplitude = 0;
		
		self.hfScale = kSFFieldSensorDefaultHFScaleCoef;
		self.hfUp = kSFFieldSensorDefaultHFUpCoef;
		self.hfK1 = kSFFieldSensorDefaultHFK1Coef;
		self.hfK2 = kSFFieldSensorDefaultHFK2Coef;
		
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
	
	[super switchOff];
}




#pragma mark -
#pragma mark Signal Processor setup


- (void)setupSignalProcessorForLowFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
}


- (void)setupSignalProcessorForHighFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
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
}




#pragma mark -
#pragma mark Calculations


- (float)calculateLowFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude;
	return value;
}


- (float)calculateHighFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	// shift by minimal value
	float value = amplitude - _smallestHighFrequencyAmplitude;
	
	// scale
	value = value * _hfScale;
	
	float Up = _hfUp;
	float K1 = _hfK1;
	float K2 = _hfK2;
	float U = MIN(value, Up) * K1 + MAX(value - Up, 0) * K2;
	
	return MAX(U, 0);
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
