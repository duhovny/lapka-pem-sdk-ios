//
//	SenseFramework/SFIdentificator.m
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import "SFIdentificator.h"
#import "SFSensorManager.h"
#import "SFAudioSessionManager.h"

#define kSFIdentificationMeanSteps		10
#define kSFIdentificationStepsToSkip	 3
#define kSFIdentificationNotHumToHumFingerprintThresholdCoef	1.51

#define kSFIdentificationFingerprintThreshold_iPhone_3GS		0.195
#define kSFIdentificationFingerprintThreshold_iPhone_4			0.191
#define kSFIdentificationFingerprintThreshold_iPhone_4S			0.225
#define kSFIdentificationFingerprintThreshold_iPhone_5			0.074
#define kSFIdentificationFingerprintThreshold_iPod_Touch_4G		0.127
#define kSFIdentificationFingerprintThreshold_iPad_2			0.225
#define kSFIdentificationFingerprintThreshold_iPad_3			0.220
#define kSFIdentificationFingerprintThreshold_iPad_4			0.074
#define kSFIdentificationFingerprintThreshold_iPad_Mini			0.074


@interface SFIdentificator () <SFSignalProcessorDelegate> {
	
	int identificationStep;
	int stepsToSkip;
	BOOL identificationIsInProcess;
	BOOL repeatIdetificationOnEUVolume;
}

@property (nonatomic) SFSensorID sensorID;
@property (nonatomic) SFSensorIdentificationFingerprint fingerprint;

- (void)identificationDidComplete;
- (SFSensorType)convertSensorIDtoSensorType:(SFSensorID)sid;

@end




@implementation SFIdentificator


#pragma mark -
#pragma mark Lifecycle


- (id)init {
	self = [super init];
	if (self) {
		
		// SIGNAL PROCESSOR
		
		self.signalProcessor = [[SFSignalProcessor alloc] init];
		self.signalProcessor.delegate = self;
		
		// default values
		_identificationThreshold = SFSensorIdentificationThreshold;
		
	}
	return self;
}


- (void)dealloc {
	
	self.signalProcessor = nil;
}


#pragma mark -
#pragma mark Identification


- (void)identificate {
	
	if (![[SFAudioSessionManager sharedManager] audioRouteIsHeadsetInOut]) {
		[self.delegate identificatorDidRecognizeSensor:SFSensorTypeUnknown];
		return;
	}
	
	if (identificationIsInProcess) return;
	
	identificationIsInProcess = YES;
	
	NSLog(@"Start identification");
	
	stepsToSkip = kSFIdentificationStepsToSkip;
	identificationStep = 0;
	
	// remove european_preference anyway
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"european_preference"];
	
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
	
	if (![self.signalProcessor start]) {
		[self.signalProcessor reboot];
		[self.signalProcessor start];
	}
}


- (void)abortIdentification {
	
	NSLog(@"abortIdentification");
	
	[self.signalProcessor stop];
	identificationIsInProcess = NO;
}


- (void)identificationDidComplete {
	
	[self.signalProcessor stop];
	
	if ([self.delegate respondsToSelector:@selector(identificatorDidObtainSensorIdentificationFingerprint:)])
		[self.delegate identificatorDidObtainSensorIdentificationFingerprint:_fingerprint];
	
	SFSensorType sensorType = [self convertSensorIDtoSensorType:_sensorID];
	
	if (sensorType != SFSensorTypeUnknown) {
		
		// if known sensor detected
		if (repeatIdetificationOnEUVolume) {
			repeatIdetificationOnEUVolume = NO;
			
			[self.delegate identificatorDidRecognizeSensor:sensorType];
			identificationIsInProcess = NO;
			
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"european_preference"];
			NSLog(@"this is EU device, set european_preference YES");
			
			if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
				[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:YES];
			
			return;
		} else {
			
			if ([self isFingerprint:_fingerprint passThresholdForSensorType:sensorType]) {
				NSLog(@"Fingerprint passes threshold");
				
				id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
				if (!european_preference) {
					
					// this is US device, set preference
					NSLog(@"this is US device, set european_preference NO");
					[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"european_preference"];
					
					if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceVolumeLimitState:)])
						[self.delegate identificatorDidRecognizeDeviceVolumeLimitState:NO];
				}
				NSLog(@"Identification complete: %@", [SFIdentificator sensorTypeToString:sensorType]);
				[self.delegate identificatorDidRecognizeSensor:sensorType];
				identificationIsInProcess = NO;
				return;
				
			} else {
				NSLog(@"Fingerprint doesn't pass threshold, continue identification");
			}
		}
	}
	
	id european_preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"european_preference"];
	if (!repeatIdetificationOnEUVolume && !european_preference) {
		NSLog(@"Repeat on EU level");
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


- (BOOL)sidlooksLikeDeviceIsEuropean:(SFSensorID)sid {
	
	// refactor: remove this method
	BOOL looksLike = NO;
	
	if ( sid.bit00 && sid.bit01 && sid.bit10 && sid.bit11 )			// 1111 - Lapka unswer in US mode on EU device
		looksLike = YES;
	
	return looksLike;
}


- (BOOL)isFingerprint:(SFSensorIdentificationFingerprint)fingerprintToCheck passThresholdForSensorType:(SFSensorType)sensorType {
	
	float fingerprintThreshold = [self fingerprintThresholdForSensorType:sensorType];
	BOOL isFingerptintPassThreshold = (fingerprintToCheck.amplitude00 > fingerprintThreshold);
	
	return isFingerptintPassThreshold;
}


- (float)fingerprintThresholdForSensorType:(SFSensorType)sensorType {
	
	float fingerprintThreshold;
	BOOL sensorIsHumidity = (sensorType == SFSensorTypeHumidity);
	SFDeviceHardwarePlatform hardwarePlatform = [[SFSensorManager sharedManager] hardwarePlatform];
	
	switch (hardwarePlatform) {
		
		case SFDeviceHardwarePlatform_iPhone_3GS:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPhone_3GS;
			break;
			
		case SFDeviceHardwarePlatform_iPhone_4:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPhone_4;
			break;
			
		case SFDeviceHardwarePlatform_iPhone_4S:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPhone_4S;
			break;
			
		case SFDeviceHardwarePlatform_iPod_Touch_5G:
		case SFDeviceHardwarePlatform_iPhone_5:
		case SFDeviceHardwarePlatform_iPhone_5C:
		case SFDeviceHardwarePlatform_iPhone_5S:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPhone_5;
			break;
			
		case SFDeviceHardwarePlatform_iPod_Touch_4G:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPod_Touch_4G;
			break;
		
		case SFDeviceHardwarePlatform_iPad_2:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPad_2;
			break;
		
		case SFDeviceHardwarePlatform_iPad_3:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPad_3;
			
		case SFDeviceHardwarePlatform_iPad_4:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPad_4;
			break;
			
		case SFDeviceHardwarePlatform_iPad_Mini:
		case SFDeviceHardwarePlatform_iPad_Mini_Retina:
		case SFDeviceHardwarePlatform_iPad_Air:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPad_Mini;
			break;
			
		default:
			fingerprintThreshold = kSFIdentificationFingerprintThreshold_iPhone_5;
			break;
	}
	
	if (sensorIsHumidity) {
		fingerprintThreshold *= kSFIdentificationNotHumToHumFingerprintThresholdCoef;
	}
	
	return fingerprintThreshold;
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
					_identificationThreshold = amplitude * 1.0 / 3.0;
					
					// tell delegate microphone level
					if ([self.delegate respondsToSelector:@selector(identificatorDidRecognizeDeviceMicrophoneLevel:)])
						[self.delegate identificatorDidRecognizeDeviceMicrophoneLevel:amplitude];
					
				}
				return;
			}
			
			BOOL bit = (amplitude >= _identificationThreshold);
			
			switch (identificationStep) {
					
				// 00
				case 0: {
					_sensorID.bit00 = bit;
					_fingerprint.amplitude00 = amplitude;
					// 01 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitZero;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 01
				case 1: {
					_sensorID.bit01 = bit;
					_fingerprint.amplitude01 = amplitude;
					// 10 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitZero;
					break;
				}	
					
				// 10
				case 2: {
					_sensorID.bit10 = bit;
					_fingerprint.amplitude10 = amplitude;
					// 11 setup
					self.signalProcessor.rightAmplitude = kSFIdentificationAmplitudeRightBitOne;
					self.signalProcessor.leftAmplitude = kSFIdentificationAmplitudeLeftBitOne;
					break;
				}
					
				// 11
				case 3: {
					_sensorID.bit11 = bit;
					_fingerprint.amplitude11 = amplitude;
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
