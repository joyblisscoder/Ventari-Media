#import "CameraBubble.h"
#import "Brand.h"
#import "DeviceCatalog.h"
#import <AVFoundation/AVFoundation.h>

static const CGFloat kBubbleSize = 180;
static NSString * const kFrameKey = @"VentariRecorderCameraBubbleFrame";

@interface CameraBubbleView : NSView
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation CameraBubbleView
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.borderWidth = 3;
        self.layer.borderColor = VRGoldColor().CGColor;
        self.layer.backgroundColor = VRBackgroundColor().CGColor;
    }
    return self;
}

- (void)layout {
    [super layout];
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
    self.previewLayer.frame = self.bounds;
}

- (void)mouseDown:(NSEvent *)event {
}

- (void)mouseDragged:(NSEvent *)event {
    NSWindow *window = self.window;
    NSRect frame = window.frame;
    frame.origin.x += event.deltaX;
    frame.origin.y += event.deltaY;
    [window setFrame:frame display:YES];
}

- (void)mouseUp:(NSEvent *)event {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VentariRecorderCameraBubbleMoved" object:self.window];
}
@end

@implementation CameraBubble {
    NSPanel *_window;
    CameraBubbleView *_view;
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_input;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSRect saved = [self savedFrame];
        NSRect frame = NSIsEmptyRect(saved) ? NSMakeRect(40, 40, kBubbleSize, kBubbleSize) : saved;
        _window = [[NSPanel alloc] initWithContentRect:frame
                                            styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
        _window.opaque = NO;
        _window.backgroundColor = NSColor.clearColor;
        _window.hasShadow = YES;
        _window.level = NSStatusWindowLevel;
        _window.hidesOnDeactivate = NO;
        _window.releasedWhenClosed = NO;
        _window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
            | NSWindowCollectionBehaviorFullScreenAuxiliary
            | NSWindowCollectionBehaviorTransient
            | NSWindowCollectionBehaviorIgnoresCycle;
        _window.sharingType = NSWindowSharingReadOnly;
        _window.movableByWindowBackground = NO;
        _window.acceptsMouseMovedEvents = YES;

        _view = [[CameraBubbleView alloc] initWithFrame:NSMakeRect(0, 0, kBubbleSize, kBubbleSize)];
        _window.contentView = _view;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(persistFrame)
                                                     name:@"VentariRecorderCameraBubbleMoved"
                                                   object:nil];
    }
    return self;
}

- (NSWindow *)window {
    return _window;
}

- (BOOL)visible {
    return _window.isVisible;
}

- (void)show {
    [self requestCameraThen:^(BOOL granted) {
        if (!granted) return;
        [self startPreview];
        if (!self->_window.isVisible) {
            if (![self frameIsOnAnyScreen:self->_window.frame]) {
                [self placeDefaultOnScreen:[NSScreen mainScreen]];
            }
            [self->_window orderFrontRegardless];
        }
    }];
}

- (void)hide {
    [_window orderOut:nil];
    [self stopPreview];
    [self persistFrame];
}

- (void)moveOntoScreen:(NSScreen *)screen ifNeeded:(BOOL)ifNeeded {
    if (!screen) return;
    NSRect frame = _window.frame;
    NSRect visible = screen.visibleFrame;
    BOOL onScreen = NSIntersectsRect(NSInsetRect(frame, 20, 20), visible);
    if (ifNeeded && onScreen) return;
    CGFloat x = NSMinX(visible) + 28;
    CGFloat y = NSMinY(visible) + 28;
    [_window setFrame:NSMakeRect(x, y, kBubbleSize, kBubbleSize) display:YES];
    [self persistFrame];
}

- (void)requestCameraThen:(void (^)(BOOL granted))completion {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        completion(YES);
        return;
    }
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted);
        });
    }];
}

- (void)startPreview {
    if (_session.isRunning) return;
    AVCaptureDevice *device = [DeviceCatalog defaultCamera];
    if (!device) return;

    if (!_session) {
        _session = [AVCaptureSession new];
        _session.sessionPreset = AVCaptureSessionPresetHigh;
    }

    [_session beginConfiguration];
    if (_input) {
        [_session removeInput:_input];
        _input = nil;
    }
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (input && [_session canAddInput:input]) {
        [_session addInput:input];
        _input = input;
    }
    [_session commitConfiguration];

    if (!_view.previewLayer) {
        AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        preview.frame = _view.bounds;
        [_view.layer insertSublayer:preview atIndex:0];
        _view.previewLayer = preview;
    } else {
        _view.previewLayer.session = _session;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self->_session startRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            AVCaptureConnection *connection = self->_view.previewLayer.connection;
            connection.automaticallyAdjustsVideoMirroring = NO;
            if (connection.isVideoMirroringSupported) {
                connection.videoMirrored = YES;
            }
        });
    });
}

- (void)stopPreview {
    AVCaptureSession *session = _session;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (session.isRunning) [session stopRunning];
    });
}

- (void)persistFrame {
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(_window.frame) forKey:kFrameKey];
}

- (NSRect)savedFrame {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kFrameKey];
    if (value.length == 0) return NSZeroRect;
    NSRect frame = NSRectFromString(value);
    if (frame.size.width < 80 || frame.size.height < 80) return NSZeroRect;
    frame.size = NSMakeSize(kBubbleSize, kBubbleSize);
    return frame;
}

- (BOOL)frameIsOnAnyScreen:(NSRect)frame {
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSIntersectsRect(frame, screen.visibleFrame)) return YES;
    }
    return NO;
}

- (void)placeDefaultOnScreen:(NSScreen *)screen {
    NSRect visible = screen.visibleFrame;
    [_window setFrame:NSMakeRect(NSMinX(visible) + 28, NSMinY(visible) + 28, kBubbleSize, kBubbleSize) display:NO];
}

@end
