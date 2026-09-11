#import "CaptureEngine.h"
#import "DeviceCatalog.h"
#import "MovieWriter.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface CaptureEngine () <SCStreamOutput, SCStreamDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@end

@implementation CaptureEngine {
    SCStream *_stream;
    dispatch_queue_t _screenQueue;
    AVCaptureSession *_audioSession;
    AVCaptureAudioDataOutput *_audioOutput;
    dispatch_queue_t _audioQueue;
    MovieWriter *_writer;
    BOOL _muted;
    BOOL _stopping;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _screenQueue = dispatch_queue_create("com.ventari.recorder.screen", DISPATCH_QUEUE_SERIAL);
        _audioQueue = dispatch_queue_create("com.ventari.recorder.audio", DISPATCH_QUEUE_SERIAL);
        _audioSession = [AVCaptureSession new];
        _audioOutput = [AVCaptureAudioDataOutput new];
    }
    return self;
}

- (void)startWithDisplay:(SCDisplay *)display
                   width:(NSInteger)width
                  height:(NSInteger)height
      microphoneEnabled:(BOOL)microphoneEnabled
           microphoneID:(NSString *)microphoneID
              outputURL:(NSURL *)outputURL
             completion:(void (^)(NSError *))completion {
    _stopping = NO;
    _muted = !microphoneEnabled;

    [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                               onScreenWindowsOnly:YES
                                                 completionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            if (completion) completion(error);
            return;
        }

        // Capture the display as-is. The camera bubble is a normal shared window so
        // it appears wherever the user dragged it. The control and countdown windows
        // use NSWindowSharingNone and are not captured.
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];

        NSInteger captureWidth = width;
        NSInteger captureHeight = height;
        if (filter.pointPixelScale > 0 && filter.contentRect.size.width > 0) {
            captureWidth = (NSInteger)round(filter.contentRect.size.width * filter.pointPixelScale);
            captureHeight = (NSInteger)round(filter.contentRect.size.height * filter.pointPixelScale);
        }
        captureWidth = MAX(2, captureWidth - (captureWidth % 2));
        captureHeight = MAX(2, captureHeight - (captureHeight % 2));
        const NSInteger maxSide = 1920;
        NSInteger longSide = MAX(captureWidth, captureHeight);
        if (longSide > maxSide) {
            CGFloat scale = (CGFloat)maxSide / (CGFloat)longSide;
            captureWidth = MAX(2, ((NSInteger)(captureWidth * scale)) & ~1);
            captureHeight = MAX(2, ((NSInteger)(captureHeight * scale)) & ~1);
        }

        NSError *writerError = nil;
        self->_writer = [[MovieWriter alloc] initWithURL:outputURL width:captureWidth height:captureHeight includeAudio:microphoneEnabled error:&writerError];
        if (!self->_writer || ![self->_writer startWritingWithError:&writerError]) {
            if (completion) completion(writerError);
            return;
        }

        if (microphoneEnabled) {
            NSError *micError = [self startAudioWithDeviceID:microphoneID];
            if (micError) {
                if (completion) completion(micError);
                return;
            }
        }

        SCStreamConfiguration *config = [SCStreamConfiguration new];
        config.width = captureWidth;
        config.height = captureHeight;
        config.minimumFrameInterval = CMTimeMake(1, 24);
        config.queueDepth = 3;
        config.showsCursor = YES;
        config.capturesAudio = NO;
        config.pixelFormat = kCVPixelFormatType_32BGRA;
        config.colorSpaceName = kCGColorSpaceSRGB;

        NSError *streamError = nil;
        self->_stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
        [self->_stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:self->_screenQueue error:&streamError];
        if (streamError) {
            if (completion) completion(streamError);
            return;
        }

        [self->_stream startCaptureWithCompletionHandler:^(NSError *startError) {
            if (completion) completion(startError);
        }];
    }];
}

- (void)stopWithCompletion:(void (^)(NSError *))completion {
    _stopping = YES;
    SCStream *stream = _stream;
    _stream = nil;
    [self stopAudio];

    void (^finishWriter)(void) = ^{
        MovieWriter *writer = self->_writer;
        self->_writer = nil;
        if (!writer) {
            if (completion) completion(nil);
            return;
        }
        [writer finishWithCompletion:completion];
    };

    if (stream) {
        [stream stopCaptureWithCompletionHandler:^(NSError *error) {
            finishWriter();
        }];
    } else {
        finishWriter();
    }
}

- (void)setMicrophoneEnabled:(BOOL)enabled {
    _muted = !enabled;
}

- (NSError *)startAudioWithDeviceID:(NSString *)deviceID {
    AVCaptureDevice *device = [DeviceCatalog microphoneWithID:deviceID] ?: [DeviceCatalog defaultMicrophone];
    if (!device) {
        return [NSError errorWithDomain:@"VentariRecorder" code:4 userInfo:@{NSLocalizedDescriptionKey: @"No microphone was found."}];
    }

    [_audioSession beginConfiguration];
    for (AVCaptureInput *input in _audioSession.inputs) {
        [_audioSession removeInput:input];
    }
    for (AVCaptureOutput *output in _audioSession.outputs) {
        [_audioSession removeOutput:output];
    }

    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input || ![_audioSession canAddInput:input]) {
        [_audioSession commitConfiguration];
        return error ?: [NSError errorWithDomain:@"VentariRecorder" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Could not open the microphone."}];
    }
    [_audioSession addInput:input];
    [_audioOutput setSampleBufferDelegate:self queue:_audioQueue];
    if ([_audioSession canAddOutput:_audioOutput]) {
        [_audioSession addOutput:_audioOutput];
    }
    [_audioSession commitConfiguration];

    dispatch_async(_audioQueue, ^{
        [self->_audioSession startRunning];
    });
    return nil;
}

- (void)stopAudio {
    dispatch_async(_audioQueue, ^{
        if (self->_audioSession.isRunning) {
            [self->_audioSession stopRunning];
        }
    });
}

- (BOOL)isCompleteFrame:(CMSampleBufferRef)sampleBuffer {
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (!attachments || CFArrayGetCount(attachments) == 0) {
        return CMSampleBufferGetImageBuffer(sampleBuffer) != NULL;
    }
    NSArray *array = (__bridge NSArray *)attachments;
    NSDictionary *info = array.lastObject;
    NSNumber *status = info[SCStreamFrameInfoStatus];
    if (!status) return YES;
    return status.integerValue == SCFrameStatusComplete;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (_stopping || type != SCStreamOutputTypeScreen || !CMSampleBufferIsValid(sampleBuffer)) return;
    if (![self isCompleteFrame:sampleBuffer]) return;
    CVPixelBufferRef screen = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!screen) return;
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    [_writer appendVideo:screen time:time];
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    if (error && self.onError && !_stopping) {
        self.onError(error);
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_stopping || _muted) return;
    [_writer appendAudio:sampleBuffer];
}

@end
