#import <Foundation/Foundation.h>
#import "DeviceCatalog.h"

@interface Recorder : NSObject
@property (nonatomic, copy) NSArray<DisplayInfo *> *displays;
@property (nonatomic, copy) NSArray<AVCaptureDevice *> *microphones;
@property (nonatomic, assign) CGDirectDisplayID selectedDisplayID;
@property (nonatomic, copy) NSString *selectedMicrophoneID;
@property (nonatomic, assign) BOOL cameraEnabled;
@property (nonatomic, assign) BOOL microphoneEnabled;
@property (nonatomic, assign, readonly) BOOL recording;
@property (nonatomic, assign, readonly) BOOL countingDown;
@property (nonatomic, assign, readonly) NSTimeInterval elapsed;
@property (nonatomic, strong, readonly) NSURL *lastSavedURL;
@property (nonatomic, weak) NSWindow *controlWindow;
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, copy) void (^onError)(NSString *message, BOOL needsScreenPermission);
@property (nonatomic, copy) void (^onAskSaveName)(NSString *suggestedName, void (^respond)(NSString *chosenName));

- (void)bootstrap;
- (void)refreshDevices;
- (void)requestScreenAccess;
- (void)start;
- (void)stop;
- (void)handleCameraToggle:(BOOL)enabled;
- (void)handleMicrophoneToggle:(BOOL)enabled;
- (void)pauseIdleHardware;
- (void)resumeIdleHardware;
- (void)openScreenRecordingSettings;
- (NSString *)elapsedLabel;
- (BOOL)canRecord;
@end
