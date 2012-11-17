//
//	SenseFramework/SFIdentificator.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFIdentificator.h"
#import "SFAudioSessionManager.h"

#define kSFIdentificationMeanSteps		10
#define kSFIdentificationStepsToSkip	 3


@interface SFIdentificator () <SFSignalProcessorDelegate> {
	
	int identificationStep;
	int stepsToSkip;
	BOOL identificationIsInProcess;
	BOOL repeatIdetificationOnEUVolume;
	SFSensorType rememberedSensorTypeUntilEUSwitchPermissionGranted;
}

@property (nonatomic, assign) SFSensorID sensorID;
@property (nonatomic, assign) SFSensorIdentificationFingerprint fingerprint;

- (void)identificationDidComplete;
- (SFSensorType)convertSensorIDtoSensorType:(SFSensorID)sid;

@end




@implementation SFIdentificator

@synthesize identificationThreshold;
@synthesize signalProcessor;
@synthesize fingerprint;
@synthesize delegate;
@synthesize sensorID;


#pragma mark -
#pragma mark Lifecycle


- (id)init {
	self = [super init];
	if (self) {
		
		// SIGNAL PROCESSOR
		
		self.signalProcessor = [[SFSignalProcessor alloc] init];
		self.signalProcessor.delegate = self;
		
		// default values
		identificationThreshold = SFSensorIdentificationThreshold;
		
	}
	return self;
}


- (void)dealloc {
	
	self.signalProcessor = nil;
}


#pragma mark -
#pragma mark Identification


- (void)identificate {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) return;
	if (identificationIsInProcess) return;
	
	identificationIsInProcess = YES;
	
	NSLog(@"Start identification");
	
	stepsToSkip = kSFIdentificationStepsToSkip;
	identificationStep = 0;
	
	// get european_preference
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (european_preference) {
		// if it was already defined – set prefered volume
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolumeToRegionMaxValue];
		NSLog(@"european_preference defined, set volume to: %g", [[SFAudioSessionManager sharedManager] hardwareOutputVolume]);
		BOOL deviceVolumeLimited = [[NSUserDefaults standardUserDefaults] boolForKey:@"european_preference"];
		if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
			[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:deviceVolumeLimited];
	} else {
		// if it wasn't defined yet — set volume depends on identification mode (normal or repeat_on_eu_level)
		float outputVolume = (repeatIdetificationOnEUVolume) ? SFAudioSessionHardwareOutputVolumeEuropeanMax : SFAudioSessionHardwareOutputVolumeDefaultMax;
		[[SFAudioSessionManager sharedManager] setHardwareOutputVolume:outputVolume];
		NSLog(@"european_preference not defined, set volume to: %g", outputVolume);
	}
	
	// setup signal processor
	self.signalProcessor.fftAnalyzer.meanSteps = kSFIdentificationMeanSteps;
	
	// set 00 amplitude
	self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitZero;
	self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitZero;
	
	[self.signalProcessor start];
}


- (void)abortIdentification {
	
	NSLog(@"abortIdentification");
	
	[self.signalProcessor stop];
	identificationIsInProcess = NO;
}


- (void)identificationDidComplete {
	
	[self.signalProcessor stop];
	
	if ([self.delegate respondsToSelector:@selector(identificatorDidObtainSensorIdentificationFingerprint:)])
		[self.delegate identificatorDidObtainSensorIdentificationFingerprint:fingerprint];
	
	SFSensorType sensorType = [self convertSensorIDtoSensorType:sensorID];
	
	if (sensorType != SFSensorTypeUnknown) {
		// if known sensor detected
		if (repeatIdetificationOnEUVolume) {
			repeatIdetificationOnEUVolume = NO;
			if ([self.delegate respondsToSelector:@selector(identificatorAskToGrantPermissionToSwitchToEU)]) {
				rememberedSensorTypeUntilEUSwitchPermissionGranted = sensorType;
				[self.delegate identificatorAskToGrantPermissionToSwitchToEU];
				return;
			} else {
				NSLog(@"Warning: Lapka sensor detected in EU mode, but we can't switch to EU because delegate doesn't response to identificatorAskToGrantPermissionToSwitchToEU method which is required if you plan to use Lapka with EU devices.");
				[self.delegate identificatorDidRecognizeSensor:SFSensorTypeUnknown];
				identificationIsInProcess = NO;
				return;
			}
		} else {
			id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
			if (!european_preference) {
				// this is US device, set preference
				NSLog(@"this is US device, set preference");
				[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"european_preference"];
				if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
					[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:NO];
			}
			NSLog(@"Identification complete: %@", [SFIdentificator sensorTypeToString:sensorType]);
			[self.delegate identificatorDidRecognizeSensor:sensorType];
			identificationIsInProcess = NO;
			return;
		}
	}
	
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (!repeatIdetificationOnEUVolume && !european_preference && [self sidlooksLikeDeviceIsEuropean:sensorID]) {
		NSLog(@"SID looks like device is European, so repeat on EU level");
		repeatIdetificationOnEUVolume = YES;
		// restart identification
		[self.signalProcessor stop];
		identificationIsInProcess = NO;
		[self identificate];
		return;
	}
	
	NSLog(@"Identification complete: %@", [SFIdentificator sensorTypeToString:sensorType]);
	[self.delegate identificatorDidRecognizeSensor:sensorType];
	
	identificationIsInProcess = NO;
	repeatIdetificationOnEUVolume = NO;
}


- (SFSensorType)convertSensorIDtoSensorType:(SFSensorID)sid {
	
	SFSensorType sensorType = SFSensorTypeUnknown;
	
	if ( sid.bit00 && sid.bit01 && sid.bit10 && !sid.bit11 )		// 1110 - Fields
		sensorType = SFSensorTypeFields;
	
	else if ( sid.bit00 && sid.bit01 && !sid.bit10 && !sid.bit11 )	// 1100 - Radiation
		sensorType = SFSensorTypeRadiation;
	
	else if ( sid.bit00 && !sid.bit01 && sid.bit10 && sid.bit11 )	// 1011 - Humidity
		sensorType = SFSensorTypeHumidity;
	
	else if ( sid.bit00 && !sid.bit01 && sid.bit10 && !sid.bit11 )	// 1010 - Nitrates
		sensorType = SFSensorTypeNitrates;
	
	else NSLog(@"SIdentificator: warning, can't identify sid %d%d%d%d", sid.bit00, sid.bit01, sid.bit10, sid.bit11);
	
	return sensorType;
}


- (void)handleFirstBitEqualZero {
	
	// first bit equal zero means this is not Lapka device, so tell delegate
	if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeNotLapkaBeingPluggedIn)])
		[self.delegate identificatorDidRecognizeNotLapkaBeingPluggedIn];
}


- (BOOL)sidlooksLikeDeviceIsEuropean:(SFSensorID)sid {
	
	BOOL looksLike = NO;
	
	if ( sid.bit00 && sid.bit01 && sid.bit10 && sid.bit11 )			// 1111 - Lapka unswer in US mode on EU device
		looksLike = YES;
	
	return looksLike;
}


#pragma mark -
#pragma mark Granted Switch To EU


- (void)userGrantedPermissionToSwitchToEU {
	
	NSLog(@"User granted permission to switch to EU");
	
	[self.delegate identificatorDidRecognizeSensor:rememberedSensorTypeUntilEUSwitchPermissionGranted];
	identificationIsInProcess = NO;
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"european_preference"];
	NSLog(@"this is EU device, set preference");
	
	if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
		[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:YES];
}


- (void)userProhibitedPermissionToSwitchToEU {
	
	NSLog(@"User prohibited permission to switch to EU");
	
	rememberedSensorTypeUntilEUSwitchPermissionGranted = SFSensorTypeUnknown;
	identificationIsInProcess = NO;
}


#pragma mark -
#pragma mark Signal Processor Delegate


- (void)signalProcessorDidUpdateMeanAmplitude:(Float32)meanAmplitude {
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			
			// Use last measure amplitude instead of mean amplitude
			Float32 amplitude = self.signalProcessor.fftAnalyzer.amplitude;
			
			// skip some steps
			if (stepsToSkip > 0) {
				stepsToSkip--;
				if (stepsToSkip == 0) {
					
					// set identification threshold to one third of microphone level
					identificationThreshold = amplitude * 1.0 / 3.0;
					
					NSLog(@"set identification threshold to half of microphone level: %g", identificationThreshold);
					
					// tell delegate microphone level
					if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceMicrophoneLevel:)])
						[self.delegate identificatorDidRecognizeDeviceMicrophoneLevel:amplitude];
					
				}
				return;
			}
			
			BOOL bit = (amplitude >= identificationThreshold);
			
			switch (identificationStep) {
					
				// 00
				case 0: {
					NSLog(@"Measure 00 bit: %d", bit?1:0);
					sensorID.bit00 = bit;
					fingerprint.amplitude00 = amplitude;
					if (bit == 0) [self handleFirstBitEqualZero];
					// 01 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitZero;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 01
				case 1: {
					NSLog(@"Measure 01 bit: %d", bit?1:0);
					sensorID.bit01 = bit;
					fingerprint.amplitude01 = amplitude;
					// 10 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitZero;
					break;
				}	
					
				// 10
				case 2: {
					NSLog(@"Measure 10 bit: %d", bit?1:0);
					sensorID.bit10 = bit;
					fingerprint.amplitude10 = amplitude;
					// 11 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 11
				case 3: {
					NSLog(@"Measure 11 bit: %d", bit?1:0);
					sensorID.bit11 = bit;
					fingerprint.amplitude11 = amplitude;
					// done
					[self identificationDidComplete];
					return;
					break;
				}
					
				default:
					break;
			}
			
			identificationStep ++;
			
		}
	});
}


/*
// amplitude debug log
 
- (void)signalProcessorDidUpdateAmplitude:(Float32)amplitude {
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			NSLog(@"left: %f right: %f amplitude: %f", self.signalProcessor.leftAmplitude, self.signalProcessor.rightAmplitude, amplitude);
		}
	});
}
*/


#pragma mark -
#pragma mark Utility


+ (NSString *)sensorTypeToString:(SFSensorType)sensorType {
	
	NSString *type;
	
	switch (sensorType) {
			
		case SFSensorTypeFields:
			type = @"EMF";
			break;
			
		case SFSensorTypeNitrates:
			type = @"Organic";
			break;
			
		case SFSensorTypeRadiation:
			type = @"Radiation";
			break;
			
		case SFSensorTypeHumidity:
			type = @"Humidity";
			break;
			
		case SFSensorTypeUnknown:
		default:
			type = @"Unknown";
			break;
	}
	
	return type;
}


@end
