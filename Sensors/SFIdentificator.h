//
//	SenseFramework/SFIdentificator.h
//	Tailored at 2012 by Bowyer, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFSignalProcessor.h"

#define kSFIdentificationAmplitudeLeftBitOne	1.0
#define kSFIdentificationAmplitudeRightBitOne	1.0
#define kSFIdentificationAmplitudeLeftBitZero	0.2
#define kSFIdentificationAmplitudeRightBitZero	0.0

#define SFSensorIdentificationThreshold	 0.08
#define SFDeviceVolumeLimitThreshold	 0.15


typedef enum {
	SFSensorTypeUnknown,
	SFSensorTypeNitrates,
	SFSensorTypeFields,
	SFSensorTypeRadiation,
	SFSensorTypeHumidity
} SFSensorType;

typedef struct {
	BOOL bit00;
	BOOL bit01;
	BOOL bit10;
	BOOL bit11;
} SFSensorID;

typedef struct {
	double amplitude00;
	double amplitude01;
	double amplitude10;
	double amplitude11;
} SFSensorIdentificationFingerprint;


@protocol SFIdentificatorDelegate <NSObject>
- (void)identificatorDidRecognizeSensor:(SFSensorType)sensorType;
@optional
- (void)identificatorDidObtainSensorIdentificationFingerprint:(SFSensorIdentificationFingerprint)fingerprint;
- (void)identificatorDidRecognizeDeviceVolumeLimitState:(BOOL)deviceVolumeIsLimited;
- (void)identificatorDidRecognizeDeviceMicrophoneLevel:(float)microphoneLevel;
@end


@interface SFIdentificator : NSObject

@property (atomic, retain) SFSignalProcessor *signalProcessor;
@property (nonatomic, assign) NSObject <SFIdentificatorDelegate> *delegate;
@property (nonatomic, assign) float identificationThreshold;
@property (nonatomic, assign) float deviceVolumeLimitThreshold;

- (void)identificate;
- (void)abortIdentification;

+ (NSString *)sensorTypeToString:(SFSensorType)sensorType;

@end
