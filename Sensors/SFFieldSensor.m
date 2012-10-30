//
//	SenseFramework/SFFieldSensor.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFFieldSensor.h"
#import "SFAudioSessionManager.h"
#import "SFIdentificator.h"

#define kSFFieldSensorDualModeMeanSteps 4		// 80ms (60ms delay + 20ms measure)
#define kSFFieldSensorSingleModeMeanSteps 25
#define kSFFieldSensorDefaultSmallestMaxForHighFrequencyField 150.0



@interface SFFieldSensor () {
	float _smallestLowFrequencyAmplitude;
	float _smallestHighFrequencyAmplitude;
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
		self.measureLowFrequencyField = YES;
		self.measureHighFrequencyField = YES;
		
		_smallestLowFrequencyAmplitude = 0;
		_smallestHighFrequencyAmplitude = kSFFieldSensorDefaultSmallestMaxForHighFrequencyField;
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
	[[SFAudioSessionManager sharedManager] setHardwareOutputVolumeToRegionMaxValue];
	
	// setup signal processor according to state
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
//	self.signalProcessor.fftAnalyzer.useSign = YES;
}


- (void)setupSignalProcessorForHighFrequencyMeasure {
	
	self.signalProcessor.leftAmplitude = kSFControlSignalBitZero;
	self.signalProcessor.rightAmplitude = kSFControlSignalBitOne;
	self.signalProcessor.fftAnalyzer.useSign = NO;
}




#pragma mark -
#pragma mark Calculations


- (float)calculateLowFrequencyFieldWithAmplitude:(Float32)amplitude {
	
//	float value = amplitude - _smallestLowFrequencyAmplitude;
	float value = amplitude;
	return value;
}


- (float)calculateHighFrequencyFieldWithAmplitude:(Float32)amplitude {
	
	float value = amplitude - _smallestHighFrequencyAmplitude;
	return MAX(value, 0);
}




#pragma mark -
#pragma mark SSignalProcessorDelegate


- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	
	if (self.dualMode) return;
	
	// single mode
	switch (state) {
			
		case kSFFieldSensorStateOff:
			break;
			
		case kSFFieldSensorStateLowFrequencyMeasurement:
		{
			
//			if (amplitude < _smallestLowFrequencyAmplitude)
//				_smallestLowFrequencyAmplitude = amplitude;
			lowFrequencyField = [self calculateLowFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateLowFrequencyField:lowFrequencyField];
			break;
		}
			
		case kSFFieldSensorStateHighFrequencyMeasurement:
		{
			if (amplitude < _smallestHighFrequencyAmplitude)
				_smallestHighFrequencyAmplitude = MAX(amplitude, 0);
			highFrequencyField = [self calculateHighFrequencyFieldWithAmplitude:amplitude];
			[self.delegate fieldSensorDidUpdateHighFrequencyField:highFrequencyField];
			break;
		}
			
		default:
			break;
	}
}


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
		
	if (self.dualMode) {
		
		switch (state) {
				
			case kSFFieldSensorStateOff:
				NSLog(@"Warning: SFieldSensor get measure result when off.");
				break;
				
			case kSFFieldSensorStateLowFrequencyMeasurement:
			{
				// last (not mean) amplitude value
				float amplitude = self.signalProcessor.fftAnalyzer.amplitude;
//				if (amplitude < _smallestLowFrequencyAmplitude)
//					_smallestLowFrequencyAmplitude = amplitude;
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
