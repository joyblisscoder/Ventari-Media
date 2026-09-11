#import "Recorder.h"
#import "Brand.h"
#import "CameraBubble.h"
#import "CaptureEngine.h"
#import "CountdownOverlay.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

@implementation Recorder {
    CaptureEngine *_engine;
    CameraBubble *_bubble;
    CountdownOverlay *_countdown;
    NSDate *_startedAt;
    NSTimer *_timer;
    NSURL *_temporaryURL;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cameraEnabled = YES;
        _microphoneEnabled = YES;
        _displays = @[];
        _microphones = @[];
        _selectedMicrophoneID = @"";
        _engine = [CaptureEngine new];
        _bubble = [CameraBubble new];
        _countdown = [CountdownOverlay new];
        __weak typeof(self) weakSelf = self;
        _engine.onError = ^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf failWithError:error];
            });
        };
    }
    return self;
}

- (void)bootstrap {
    self.controlWindow.sharingType = NSWindowSharingNone;
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(screensChanged:)
                                               name:NSApplicationDidChangeScreenParametersNotification
                                             object:nil];
    [self refreshDevices];
    if (self.cameraEnabled) {
        [_bubble show];
        [_bubble setBackgroundBlurEnabled:self.backgroundBlurEnabled];
    }
}

- (void)requestScreenAccess {
    [self refreshDevices];
}

- (void)screensChanged:(NSNotification *)notification {
    if (self.recording) return;
    [self refreshDevices];
}

- (void)refreshDevices {
    NSArray<AVCaptureDevice *> *mics = [DeviceCatalog microphones];
    self.microphones = mics;
    BOOL stillValid = NO;
    for (AVCaptureDevice *mic in mics) {
        if ([mic.uniqueID isEqualToString:self.selectedMicrophoneID]) {
            stillValid = YES;
            break;
        }
    }
    if (!stillValid) {
        self.selectedMicrophoneID = [DeviceCatalog defaultMicrophone].uniqueID ?: @"";
    }

    [DeviceCatalog loadDisplaysWithCompletion:^(NSArray<DisplayInfo *> *displays, NSError *error) {
        self.displays = displays ?: @[];
        BOOL displayValid = NO;
        for (DisplayInfo *info in self.displays) {
            if (info.displayID == self.selectedDisplayID) {
                displayValid = YES;
                break;
            }
        }
        if (!displayValid) {
            CGDirectDisplayID mainID = 0;
            NSNumber *number = [NSScreen mainScreen].deviceDescription[@"NSScreenNumber"];
            if (number) mainID = number.unsignedIntValue;
            BOOL usedMain = NO;
            for (DisplayInfo *info in self.displays) {
                if (info.displayID == mainID) {
                    self.selectedDisplayID = mainID;
                    usedMain = YES;
                    break;
                }
            }
            if (!usedMain) {
                self.selectedDisplayID = self.displays.firstObject.displayID;
            }
        }
        if (self.onChange) self.onChange();
    }];
}

- (BOOL)canRecord {
    return self.displays.count > 0 && self.selectedDisplayID != 0 && !self.recording && !self.countingDown;
}

- (NSString *)elapsedLabel {
    NSInteger total = (NSInteger)self.elapsed;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

- (void)handleCameraToggle:(BOOL)enabled {
    _cameraEnabled = enabled;
    if (enabled) {
        [_bubble show];
        [_bubble setBackgroundBlurEnabled:self.backgroundBlurEnabled];
    } else {
        [_bubble hide];
    }
}

- (void)handleBlurToggle:(BOOL)enabled {
    _backgroundBlurEnabled = enabled;
    [_bubble setBackgroundBlurEnabled:enabled];
}

- (void)pauseIdleHardware {
    if (self.recording || self.countingDown) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:VRMediaPauseIdleEffectsNotification object:self];
}

- (void)resumeIdleHardware {
    if (self.cameraEnabled) {
        [_bubble show];
        [_bubble setBackgroundBlurEnabled:self.backgroundBlurEnabled];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:VRMediaResumeIdleEffectsNotification object:self];
}

- (void)handleMicrophoneToggle:(BOOL)enabled {
    _microphoneEnabled = enabled;
    if (self.recording) {
        [_engine setMicrophoneEnabled:enabled];
    }
}

- (void)start {
    if (self.recording || self.countingDown) return;

    DisplayInfo *selected = nil;
    for (DisplayInfo *info in self.displays) {
        if (info.displayID == self.selectedDisplayID) {
            selected = info;
            break;
        }
    }
    if (!selected) {
        if (self.onError) self.onError(@"Choose a screen to record.", NO);
        return;
    }

    if (self.cameraEnabled) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
            if (self.onError) self.onError(@"Allow Camera access for Ventari Media in System Settings.", NO);
            return;
        }
        if (status != AVAuthorizationStatusAuthorized) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!granted) {
                        if (self.onError) self.onError(@"Allow Camera access for Ventari Media in System Settings.", NO);
                        return;
                    }
                    [self start];
                });
            }];
            return;
        }
    }

    if (self.microphoneEnabled) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (status != AVAuthorizationStatusAuthorized) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!granted) {
                        if (self.onError) self.onError(@"Allow Microphone access for Ventari Media in System Settings.", NO);
                        return;
                    }
                    [self start];
                });
            }];
            return;
        }
        if (self.selectedMicrophoneID.length == 0) {
            if (self.onError) self.onError(@"No microphone was found.", NO);
            return;
        }
    }

    if (self.cameraEnabled) {
        [_bubble show];
        [_bubble setBackgroundBlurEnabled:self.backgroundBlurEnabled];
        [_bubble moveOntoScreen:[self screenForDisplayID:selected.displayID] ifNeeded:YES];
    }

    _countingDown = YES;
    if (self.onChange) self.onChange();

    NSScreen *target = [self screenForDisplayID:selected.displayID];
    NSArray<NSScreen *> *countdownScreens = target ? @[target] : [NSScreen screens];
    __weak typeof(self) weakSelf = self;
    [_countdown runOnScreens:countdownScreens completion:^(BOOL cancelled) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self->_countingDown = NO;
        if (cancelled) {
            if (self.onChange) self.onChange();
            return;
        }
        [self beginCaptureForDisplay:selected];
    }];
}

- (void)beginCaptureForDisplay:(DisplayInfo *)selected {
    NSURL *url = [self makeTemporaryURL];
    _temporaryURL = url;
    _lastSavedURL = nil;

    [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                               onScreenWindowsOnly:YES
                                                 completionHandler:^(SCShareableContent *content, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !content) {
                [self failWithError:error];
                return;
            }
            SCDisplay *display = [DeviceCatalog shareableDisplayWithID:selected.displayID inContent:content];
            if (!display) {
                if (self.onError) self.onError(@"That screen is no longer available.", NO);
                return;
            }
            [self->_engine startWithDisplay:display
                                      width:selected.width
                                     height:selected.height
                         microphoneEnabled:self.microphoneEnabled
                              microphoneID:self.selectedMicrophoneID
                                 outputURL:url
                                completion:^(NSError *startError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (startError) {
                        [self failWithError:startError];
                        return;
                    }
                    self->_recording = YES;
                    self->_startedAt = [NSDate date];
                    self->_elapsed = 0;
                    [self startTimer];
                    if (self.onChange) self.onChange();
                });
            }];
        });
    }];
}

- (NSScreen *)screenForDisplayID:(CGDirectDisplayID)displayID {
    for (NSScreen *screen in [NSScreen screens]) {
        NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
        if (number.unsignedIntValue == displayID) return screen;
    }
    return [NSScreen mainScreen];
}

- (void)stop {
    if (self.countingDown) {
        [_countdown cancel];
        _countingDown = NO;
        if (self.onChange) self.onChange();
        return;
    }
    if (!self.recording) return;
    _recording = NO;
    [self stopTimer];
    if (self.onChange) self.onChange();

    [_engine stopWithCompletion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self failWithError:error];
                return;
            }
            [self promptToNameRecording];
        });
    }];
}

- (void)openScreenRecordingSettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)startTimer {
    [self stopTimer];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
        if (self->_startedAt) {
            self->_elapsed = [[NSDate date] timeIntervalSinceDate:self->_startedAt];
            if (self.onChange) self.onChange();
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [_timer invalidate];
    _timer = nil;
}

- (NSURL *)makeTemporaryURL {
    NSString *name = [NSString stringWithFormat:@"ventari-recorder-%@.mp4", NSUUID.UUID.UUIDString];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

- (NSString *)suggestedName {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd 'at' HH.mm.ss";
    return [NSString stringWithFormat:@"Recording %@", [formatter stringFromDate:[NSDate date]]];
}

- (void)promptToNameRecording {
    NSURL *temp = _temporaryURL;
    if (!temp) {
        if (self.onChange) self.onChange();
        return;
    }
    NSString *suggested = [self suggestedName];
    if (!self.onAskSaveName) {
        [self finishSaveWithName:suggested tempURL:temp];
        return;
    }
    self.onAskSaveName(suggested, ^(NSString *chosen) {
        [self finishSaveWithName:chosen tempURL:temp];
    });
}

- (void)finishSaveWithName:(NSString *)chosen tempURL:(NSURL *)temp {
    _temporaryURL = nil;
    if (chosen.length == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:temp error:nil];
        self->_lastSavedURL = nil;
        if (self.onChange) self.onChange();
        return;
    }

    NSString *name = [self sanitizedFileName:chosen];
    if (name.length == 0) name = [self suggestedName];
    if (![[name.pathExtension lowercaseString] isEqualToString:@"mp4"]) {
        name = [name stringByAppendingPathExtension:@"mp4"];
    }
    NSURL *desktop = [[[NSFileManager defaultManager] homeDirectoryForCurrentUser] URLByAppendingPathComponent:@"Desktop" isDirectory:YES];
    NSURL *dest = [self uniqueURL:[desktop URLByAppendingPathComponent:name]];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:temp toURL:dest error:&error]) {
        [[NSFileManager defaultManager] removeItemAtURL:temp error:nil];
        if (self.onError) self.onError(error.localizedDescription ?: @"Could not save the recording.", NO);
        if (self.onChange) self.onChange();
        return;
    }
    self->_lastSavedURL = dest;
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[dest]];
    if (self.onChange) self.onChange();
}

- (NSString *)sanitizedFileName:(NSString *)raw {
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([[trimmed.pathExtension lowercaseString] isEqualToString:@"mp4"]) {
        trimmed = trimmed.stringByDeletingPathExtension;
    }
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@":/\\?%*|\"<>"];
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        unichar outc = [illegal characterIsMember:c] ? (unichar)'-' : c;
        [clean appendFormat:@"%C", outc];
    }
    while ([clean hasPrefix:@"."]) {
        [clean deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    return clean;
}

- (NSURL *)uniqueURL:(NSURL *)url {
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return url;
    NSString *base = url.URLByDeletingPathExtension.lastPathComponent;
    NSURL *folder = url.URLByDeletingLastPathComponent;
    for (NSInteger i = 2; i < 100; i++) {
        NSURL *candidate = [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"%@ %ld.mp4", base, (long)i]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) return candidate;
    }
    return url;
}

- (void)failWithError:(NSError *)error {
    NSString *domain = error.domain ?: @"";
    BOOL needsScreen = [domain containsString:@"ScreenCapture"]
        || [domain containsString:@"TCC"]
        || error.code == -3801
        || error.code == -17394;
    NSString *message = error.localizedDescription ?: @"Recording failed.";
    if (needsScreen) {
        message = @"macOS blocked screen capture. In System Settings → Privacy & Security → Screen & System Audio Recording, turn Ventari Media off and on, then quit and reopen the app.";
    }
    if (self.recording) {
        [self stop];
    }
    if (self.onError) self.onError(message, needsScreen);
}

@end
