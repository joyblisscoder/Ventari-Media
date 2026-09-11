#import "CameraBubble.h"
#import "Brand.h"
#import "DeviceCatalog.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <Vision/Vision.h>

static const CGFloat kMinBubbleSize = 120;
static const CGFloat kDefaultBubbleSize = 180;
static const CGFloat kHandleSize = 22;
static NSString * const kFrameKey = @"VentariRecorderCameraBubbleFrame";

static NSRect VRHomeScreen(NSRect frame) {
    NSRect home = NSZeroRect;
    CGFloat bestArea = -1;
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    for (NSScreen *screen in [NSScreen screens]) {
        NSRect visible = screen.visibleFrame;
        if (NSPointInRect(center, visible) || NSIntersectsRect(frame, visible)) {
            NSRect overlap = NSIntersectionRect(frame, visible);
            CGFloat area = NSWidth(overlap) * NSHeight(overlap);
            if (area > bestArea) {
                bestArea = area;
                home = visible;
            }
        }
    }
    if (NSIsEmptyRect(home)) {
        home = [NSScreen mainScreen].visibleFrame;
    }
    return home;
}

static CGFloat VRMaxBubbleSizeForRect(NSRect visible) {
    // Half the shorter edge is a circle that covers about a quarter of the screen.
    return MAX(kMinBubbleSize, MIN(visible.size.width, visible.size.height) * 0.5);
}

static NSRect VRClampedBubbleFrame(NSRect frame) {
    NSRect home = VRHomeScreen(frame);
    CGFloat maxS = VRMaxBubbleSizeForRect(home);
    CGFloat side = MIN(frame.size.width, frame.size.height);
    if (side < 1) side = kDefaultBubbleSize;
    side = MIN(MAX(side, kMinBubbleSize), maxS);
    frame.size = NSMakeSize(side, side);
    CGFloat maxX = NSMaxX(home) - side;
    CGFloat maxY = NSMaxY(home) - side;
    frame.origin.x = MIN(MAX(frame.origin.x, NSMinX(home)), MAX(NSMinX(home), maxX));
    frame.origin.y = MIN(MAX(frame.origin.y, NSMinY(home)), MAX(NSMinY(home), maxY));
    return frame;
}

@interface CameraBubbleView : NSView
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) CALayer *processedLayer;
@property (nonatomic, assign) NSPoint dragOffset;
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
        CALayer *processed = [CALayer layer];
        processed.frame = self.bounds;
        processed.contentsGravity = kCAGravityResizeAspectFill;
        processed.hidden = YES;
        [self.layer insertSublayer:processed atIndex:0];
        self.processedLayer = processed;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    return self;
}

- (void)layout {
    [super layout];
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
    self.previewLayer.frame = self.bounds;
    self.processedLayer.frame = self.bounds;
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint mouse = [NSEvent mouseLocation];
    NSRect frame = self.window.frame;
    self.dragOffset = NSMakePoint(mouse.x - frame.origin.x, mouse.y - frame.origin.y);
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint mouse = [NSEvent mouseLocation];
    NSRect frame = self.window.frame;
    frame.origin.x = mouse.x - self.dragOffset.x;
    frame.origin.y = mouse.y - self.dragOffset.y;
    [self.window setFrame:VRClampedBubbleFrame(frame) display:NO];
}

- (void)mouseUp:(NSEvent *)event {
    NSWindow *window = self.window;
    [window setFrame:VRClampedBubbleFrame(window.frame) display:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VentariRecorderCameraBubbleMoved" object:window];
}
@end

@interface VRResizeHandle : NSView
@property (nonatomic, assign) BOOL dragging;
@property (nonatomic, assign) CGFloat startSize;
@property (nonatomic, assign) NSPoint startMouse;
@property (nonatomic, assign) NSPoint startTopLeft;
@end

@implementation VRResizeHandle
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.backgroundColor = VRGoldColor().CGColor;
        self.hidden = YES;
        NSImageView *icon = [NSImageView new];
        icon.image = [NSImage imageWithSystemSymbolName:@"arrow.up.left.and.arrow.down.right" accessibilityDescription:@"Resize"];
        icon.imageScaling = NSImageScaleProportionallyDown;
        icon.contentTintColor = VRBackgroundColor();
        icon.frame = NSInsetRect(self.bounds, 4, 4);
        icon.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:icon];
    }
    return self;
}

- (void)resetCursorRects {
    [self addCursorRect:self.bounds cursor:[NSCursor crosshairCursor]];
}

- (void)mouseDown:(NSEvent *)event {
    self.dragging = YES;
    NSRect frame = self.window.frame;
    self.startSize = MIN(frame.size.width, frame.size.height);
    self.startMouse = [NSEvent mouseLocation];
    self.startTopLeft = NSMakePoint(NSMinX(frame), NSMaxY(frame));
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint mouse = [NSEvent mouseLocation];
    CGFloat dx = mouse.x - self.startMouse.x;
    CGFloat dy = mouse.y - self.startMouse.y;
    CGFloat side = self.startSize + dx - dy;
    NSRect frame = NSZeroRect;
    frame.size = NSMakeSize(side, side);
    frame.origin.x = self.startTopLeft.x;
    frame.origin.y = self.startTopLeft.y - side;
    [self.window setFrame:VRClampedBubbleFrame(frame) display:NO];
}

- (void)mouseUp:(NSEvent *)event {
    self.dragging = NO;
    NSWindow *window = self.window;
    [window setFrame:VRClampedBubbleFrame(window.frame) display:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VentariRecorderCameraBubbleMoved" object:window];
    if (!NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VentariRecorderCameraBubbleHoverEnded" object:window];
    }
}
@end

@interface VRBubbleChrome : NSView
@property (nonatomic, strong) CameraBubbleView *bubbleView;
@property (nonatomic, strong) VRResizeHandle *handle;
@end

@implementation VRBubbleChrome
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.clearColor.CGColor;
        _bubbleView = [[CameraBubbleView alloc] initWithFrame:self.bounds];
        [self addSubview:_bubbleView];
        _handle = [[VRResizeHandle alloc] initWithFrame:NSMakeRect(0, 0, kHandleSize, kHandleSize)];
        [self addSubview:_handle];
        [self layoutHandle];
    }
    return self;
}

- (void)layout {
    [super layout];
    self.bubbleView.frame = self.bounds;
    [self layoutHandle];
}

- (void)layoutHandle {
    NSRect bounds = self.bounds;
    self.handle.frame = NSMakeRect(NSMaxX(bounds) - kHandleSize, 0, kHandleSize, kHandleSize);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in [self.trackingAreas copy]) {
        [self removeTrackingArea:area];
    }
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect)
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
}

- (void)mouseEntered:(NSEvent *)event {
    self.handle.hidden = NO;
}

- (void)mouseExited:(NSEvent *)event {
    if (!self.handle.dragging) {
        self.handle.hidden = YES;
    }
}
@end

@interface CameraBubble () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation CameraBubble {
    NSPanel *_window;
    VRBubbleChrome *_chrome;
    CameraBubbleView *_view;
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_input;
    AVCaptureVideoDataOutput *_videoOutput;
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _visionQueue;
    BOOL _wantPreview;
    BOOL _blurEnabled;
    CIContext *_ciContext;
    VNGeneratePersonSegmentationRequest *_personRequest;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionQueue = dispatch_queue_create("com.ventari.recorder.camera", DISPATCH_QUEUE_SERIAL);
        _visionQueue = dispatch_queue_create("com.ventari.recorder.vision", DISPATCH_QUEUE_SERIAL);
        _ciContext = [CIContext contextWithOptions:@{kCIContextCacheIntermediates: @NO}];
        NSRect saved = [self savedFrame];
        NSRect frame = NSIsEmptyRect(saved) ? NSMakeRect(40, 40, kDefaultBubbleSize, kDefaultBubbleSize) : saved;
        frame = VRClampedBubbleFrame(frame);
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

        _chrome = [[VRBubbleChrome alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
        _view = _chrome.bubbleView;
        _window.contentView = _chrome;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(persistFrame)
                                                     name:@"VentariRecorderCameraBubbleMoved"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleHoverEnded)
                                                     name:@"VentariRecorderCameraBubbleHoverEnded"
                                                   object:nil];
    }
    return self;
}

- (void)handleHoverEnded {
    if (!_chrome.handle.dragging) {
        _chrome.handle.hidden = YES;
    }
}

- (NSWindow *)window {
    return _window;
}

- (BOOL)visible {
    return _window.isVisible;
}

- (void)show {
    [self clampToVisibleScreens];
    [_window orderFrontRegardless];
    [self requestCameraThen:^(BOOL granted) {
        if (!granted) return;
        [self startPreview];
        [self clampToVisibleScreens];
        [self->_window orderFrontRegardless];
    }];
}

- (void)hide {
    [_window orderOut:nil];
    [self stopPreview];
    [self persistFrame];
}

- (void)pausePreview {
    [self stopPreview];
}

- (void)resumePreview {
    if (!_window.isVisible) return;
    [self startPreview];
}

- (void)moveOntoScreen:(NSScreen *)screen ifNeeded:(BOOL)ifNeeded {
    if (!screen) {
        [self clampToVisibleScreens];
        return;
    }
    NSRect visible = screen.visibleFrame;
    NSRect frame = _window.frame;
    BOOL fullyOn = NSContainsRect(visible, frame);
    if (ifNeeded && fullyOn) return;
    if (fullyOn) {
        [self clampToVisibleScreens];
        return;
    }
    frame.origin.x = NSMinX(visible) + 28;
    frame.origin.y = NSMinY(visible) + 28;
    [_window setFrame:VRClampedBubbleFrame(frame) display:YES];
    [self persistFrame];
}

- (void)clampToVisibleScreens {
    NSRect clamped = VRClampedBubbleFrame(_window.frame);
    if (!NSEqualRects(clamped, _window.frame)) {
        [_window setFrame:clamped display:YES];
        [self persistFrame];
    }
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
    _wantPreview = YES;
    dispatch_async(_sessionQueue, ^{
        [self startPreviewOnQueue];
    });
}

- (void)stopPreview {
    _wantPreview = NO;
    dispatch_async(_sessionQueue, ^{
        if (self->_session.isRunning) {
            [self->_session stopRunning];
        }
    });
}

- (void)startPreviewOnQueue {
    if (!_wantPreview) return;
    if (_session.isRunning) return;

    AVCaptureDevice *device = [DeviceCatalog defaultCamera];
    if (!device) return;

    if (!_session) {
        _session = [AVCaptureSession new];
        if ([_session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
            _session.sessionPreset = AVCaptureSessionPresetMedium;
        }
    }

    if (!_input || !_videoOutput) {
        [_session beginConfiguration];
        if (!_input) {
            NSError *error = nil;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if (input && [_session canAddInput:input]) {
                [_session addInput:input];
                _input = input;
            }
        }
        [self attachVideoOutputLocked];
        [_session commitConfiguration];
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
        if (!self->_view.previewLayer) {
            AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:self->_session];
            preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
            preview.frame = self->_view.bounds;
            [self->_view.layer insertSublayer:preview atIndex:0];
            self->_view.previewLayer = preview;
        } else {
            self->_view.previewLayer.session = self->_session;
        }
    });

    [self applyBlurPresentation];
    [_session startRunning];

    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureConnection *connection = self->_view.previewLayer.connection;
        connection.automaticallyAdjustsVideoMirroring = NO;
        if (connection.isVideoMirroringSupported) {
            connection.videoMirrored = YES;
        }
    });
}

- (void)setBackgroundBlurEnabled:(BOOL)enabled {
    _blurEnabled = enabled;
    [self applyBlurPresentation];
    dispatch_async(_sessionQueue, ^{
        if (!self->_session) return;
        if (self->_videoOutput) return;
        [self->_session beginConfiguration];
        [self attachVideoOutputLocked];
        [self->_session commitConfiguration];
    });
}

- (void)applyBlurPresentation {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_view.previewLayer.hidden = self->_blurEnabled;
        self->_view.processedLayer.hidden = !self->_blurEnabled;
    });
}

- (void)attachVideoOutputLocked {
    if (_videoOutput) return;
    _videoOutput = [AVCaptureVideoDataOutput new];
    _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    _videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
    [_videoOutput setSampleBufferDelegate:self queue:_visionQueue];
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_wantPreview || !_blurEnabled) return;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;
    [self renderBlurredFrame:pixelBuffer];
}

- (void)renderBlurredFrame:(CVPixelBufferRef)pixelBuffer {
    if (!_personRequest) {
        _personRequest = [[VNGeneratePersonSegmentationRequest alloc] init];
        _personRequest.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelFast;
        _personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    }

    CIImage *person = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if (person.extent.size.width < 1) return;

    CGFloat visionScale = MIN(1.0, 360.0 / person.extent.size.width);
    CIImage *visionInput = person;
    if (visionScale < 0.999) {
        visionInput = [person imageByApplyingTransform:CGAffineTransformMakeScale(visionScale, visionScale)];
    }

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:visionInput options:@{}];
    NSError *error = nil;
    if (![handler performRequests:@[_personRequest] error:&error]) return;
    VNPixelBufferObservation *observation = _personRequest.results.firstObject;
    if (![observation isKindOfClass:[VNPixelBufferObservation class]]) return;

    CIImage *mask = [CIImage imageWithCVPixelBuffer:observation.pixelBuffer];
    if (mask.extent.size.width < 1) return;
    CGFloat scaleX = person.extent.size.width / mask.extent.size.width;
    CGFloat scaleY = person.extent.size.height / mask.extent.size.height;
    mask = [mask imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    mask = [[mask imageByApplyingGaussianBlurWithSigma:1.5] imageByCroppingToRect:person.extent];

    const CGFloat down = 0.22;
    CIImage *tiny = [person imageByApplyingTransform:CGAffineTransformMakeScale(down, down)];
    tiny = [tiny imageByClampingToExtent];
    CIImage *blurred = [tiny imageByApplyingGaussianBlurWithSigma:9.0];
    blurred = [blurred imageByApplyingTransform:CGAffineTransformMakeScale(1.0 / down, 1.0 / down)];
    blurred = [blurred imageByCroppingToRect:person.extent];

    CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blend setValue:person forKey:kCIInputImageKey];
    [blend setValue:blurred forKey:kCIInputBackgroundImageKey];
    [blend setValue:mask forKey:kCIInputMaskImageKey];
    CIImage *output = blend.outputImage;
    if (!output) return;

    CGAffineTransform flip = CGAffineTransformMakeTranslation(person.extent.size.width, 0);
    flip = CGAffineTransformScale(flip, -1, 1);
    output = [[output imageByApplyingTransform:flip] imageByCroppingToRect:person.extent];

    CGImageRef cgImage = [_ciContext createCGImage:output fromRect:person.extent];
    if (!cgImage) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_view.processedLayer.contents = CFBridgingRelease(cgImage);
    });
}

- (void)persistFrame {
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(_window.frame) forKey:kFrameKey];
}

- (NSRect)savedFrame {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kFrameKey];
    if (value.length == 0) return NSZeroRect;
    NSRect frame = NSRectFromString(value);
    if (frame.size.width < kMinBubbleSize || frame.size.height < kMinBubbleSize) return NSZeroRect;
    CGFloat side = MIN(frame.size.width, frame.size.height);
    frame.size = NSMakeSize(side, side);
    return frame;
}

- (void)placeDefaultOnScreen:(NSScreen *)screen {
    NSRect visible = screen.visibleFrame;
    [_window setFrame:NSMakeRect(NSMinX(visible) + 28, NSMinY(visible) + 28, kDefaultBubbleSize, kDefaultBubbleSize) display:NO];
}

@end
