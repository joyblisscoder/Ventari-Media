#import <AVFoundation/AVFoundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

@interface DisplayInfo : NSObject
@property (nonatomic, assign) CGDirectDisplayID displayID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, readonly) NSString *menuTitle;
@end

@interface DeviceCatalog : NSObject
+ (void)loadDisplaysWithCompletion:(void (^)(NSArray<DisplayInfo *> *displays, NSError *error))completion;
+ (SCDisplay *)shareableDisplayWithID:(CGDirectDisplayID)displayID inContent:(SCShareableContent *)content;
+ (NSArray<AVCaptureDevice *> *)microphones;
+ (AVCaptureDevice *)defaultMicrophone;
+ (AVCaptureDevice *)microphoneWithID:(NSString *)uniqueID;
+ (AVCaptureDevice *)defaultCamera;
+ (NSArray<SCRunningApplication *> *)applicationsMatchingBundleID:(NSString *)bundleID inContent:(SCShareableContent *)content;
@end
