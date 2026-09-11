#import "DeviceCatalog.h"
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation DisplayInfo
- (NSString *)menuTitle {
    return [NSString stringWithFormat:@"%@ (%ld×%ld)", self.name, (long)self.width, (long)self.height];
}
@end

@implementation DeviceCatalog

+ (void)loadDisplaysWithCompletion:(void (^)(NSArray<DisplayInfo *> *, NSError *))completion {
    // List screens from NSScreen so the picker works without probing TCC.
    // ScreenCaptureKit is only used when a recording actually starts.
    NSMutableArray<DisplayInfo *> *items = [NSMutableArray array];
    for (NSScreen *screen in [NSScreen screens]) {
        NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
        CGDirectDisplayID displayID = number.unsignedIntValue;
        CGFloat scale = screen.backingScaleFactor > 0 ? screen.backingScaleFactor : 1;
        DisplayInfo *info = [DisplayInfo new];
        info.displayID = displayID;
        info.name = screen.localizedName.length ? screen.localizedName : [NSString stringWithFormat:@"Display %u", displayID];
        info.width = MAX((NSInteger)(screen.frame.size.width * scale), (NSInteger)CGDisplayPixelsWide(displayID));
        info.height = MAX((NSInteger)(screen.frame.size.height * scale), (NSInteger)CGDisplayPixelsHigh(displayID));
        [items addObject:info];
    }
    [items sortUsingComparator:^NSComparisonResult(DisplayInfo *a, DisplayInfo *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(items, nil);
    });
}

+ (SCDisplay *)shareableDisplayWithID:(CGDirectDisplayID)displayID inContent:(SCShareableContent *)content {
    for (SCDisplay *display in content.displays) {
        if (display.displayID == displayID) return display;
    }
    return nil;
}

+ (NSArray<AVCaptureDevice *> *)microphones {
    AVCaptureDeviceDiscoverySession *session =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeMicrophone,
            AVCaptureDeviceTypeExternal
        ]
                                                              mediaType:AVMediaTypeAudio
                                                               position:AVCaptureDevicePositionUnspecified];
    return session.devices ?: @[];
}

+ (AVCaptureDevice *)defaultMicrophone {
    NSArray<AVCaptureDevice *> *mics = [self microphones];
    for (AVCaptureDevice *device in mics) {
        if ([device.localizedName localizedCaseInsensitiveContainsString:@"MacBook"]) {
            return device;
        }
    }
    for (AVCaptureDevice *device in mics) {
        if ([device.localizedName localizedCaseInsensitiveContainsString:@"Built-in"]) {
            return device;
        }
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] ?: mics.firstObject;
}

+ (AVCaptureDevice *)microphoneWithID:(NSString *)uniqueID {
    if (uniqueID.length == 0) return nil;
    return [AVCaptureDevice deviceWithUniqueID:uniqueID];
}

+ (AVCaptureDevice *)defaultCamera {
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionUnspecified];
    if (camera) return camera;
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

+ (NSArray<SCRunningApplication *> *)applicationsMatchingBundleID:(NSString *)bundleID inContent:(SCShareableContent *)content {
    if (bundleID.length == 0) return @[];
    NSMutableArray *matches = [NSMutableArray array];
    for (SCRunningApplication *app in content.applications) {
        if ([app.bundleIdentifier isEqualToString:bundleID]) {
            [matches addObject:app];
        }
    }
    return matches;
}

@end
