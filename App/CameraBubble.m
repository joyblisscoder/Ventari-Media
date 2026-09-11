#import "CameraBubble.h"
#import "Brand.h"
#import "DeviceCatalog.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <Vision/Vision.h>

static const CGFloat kBubbleSize = 180;
static NSString * const kFrameKey = @"VentariRecorderCameraBubbleFrame";

static NSRect VRClampedBubbleFrame(NSRect frame) {
    frame.size = NSMakeSize(kBubbleSize, kBubbleSize);
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
    CGFloat maxX = NSMaxX(home) - kBubbleSize;
    CGFloat maxY = NSMaxY(home) - kBubbleSize;
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

@interface CameraBubble () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation CameraBubble {
    NSPanel *_window;
    CameraBubbleView *_view;
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_input;
    AVCaptureVideoDataOutput *_videoOutput;
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _visionQueue;
    BOOL _wantPreview;
    BOOL _blurEnabled;
    BOOL _blurBusy;
    CIContext *_ciContext;
    VNGeneratePersonSegmentationRequest *_personRequest;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionQueue = dispatch_queue_create("com.ventari.recorder.camera", DISPATCH_QUEUE_SERIAL);
        _visionQueue = dispatch_queue_create("com.ventari.recorder.vision", DISPATCH_QUEUE_SERIAL);
        _ciContext = [CIContext contextWithOptions:nil];
        NSRect saved = [self savedFrame];
        NSRect frame = NSIsEmptyRect(saved) ? NSMakeRect(40, 40, kBubbleSize, kBubbleSize) : saved;
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
    if (!_wantPreview || !_blurEnabled || _blurBusy) return;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;
    _blurBusy = YES;
    [self renderBlurredFrame:pixelBuffer];
    _blurBusy = NO;
}

- (void)renderBlurredFrame:(CVPixelBufferRef)pixelBuffer {
    if (!_personRequest) {
        _personRequest = [[VNGeneratePersonSegmentationRequest alloc] init];
        _personRequest.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelBalanced;
        _personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    }

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    NSError *error = nil;
    if (![handler performRequests:@[_personRequest] error:&error]) return;
    VNPixelBufferObservation *observation = _personRequest.results.firstObject;
    if (![observation isKindOfClass:[VNPixelBufferObservation class]]) return;

    CIImage *person = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIImage *mask = [CIImage imageWithCVPixelBuffer:observation.pixelBuffer];
    if (mask.extent.size.width < 1 || person.extent.size.width < 1) return;
    CGFloat scaleX = person.extent.size.width / mask.extent.size.width;
    CGFloat scaleY = person.extent.size.height / mask.extent.size.height;
    mask = [mask imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    mask = [[mask imageByApplyingGaussianBlurWithSigma:4.0] imageByCroppingToRect:person.extent];

    CIImage *clamped = [person imageByClampingToExtent];
    CIImage *blurred = [[clamped imageByApplyingGaussianBlurWithSigma:40.0] imageByCroppingToRect:person.extent];

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
