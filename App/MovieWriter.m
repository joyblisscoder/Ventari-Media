#import "MovieWriter.h"

@implementation MovieWriter {
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInputPixelBufferAdaptor *_adaptor;
    AVAssetWriterInput *_audioInput;
    BOOL _sessionStarted;
    NSLock *_lock;
}

- (instancetype)initWithURL:(NSURL *)url
                      width:(NSInteger)width
                     height:(NSInteger)height
               includeAudio:(BOOL)includeAudio
                      error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    _lock = [NSLock new];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }

    NSInteger evenWidth = MAX(2, width - (width % 2));
    NSInteger evenHeight = MAX(2, height - (height % 2));
    NSError *writerError = nil;
    _writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&writerError];
    if (!_writer) {
        if (error) *error = writerError;
        return nil;
    }

    NSInteger bitrate = MIN(20000000, MAX(4000000, evenWidth * evenHeight * 4));
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(evenWidth),
        AVVideoHeightKey: @(evenHeight),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(bitrate),
            AVVideoExpectedSourceFrameRateKey: @30,
            AVVideoMaxKeyFrameIntervalKey: @60,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        }
    };

    _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    _videoInput.expectsMediaDataInRealTime = YES;
    if (![_writer canAddInput:_videoInput]) {
        if (error) *error = [NSError errorWithDomain:@"VentariRecorder" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Could not add the video track."}];
        return nil;
    }
    [_writer addInput:_videoInput];

    _adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:@{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(evenWidth),
        (id)kCVPixelBufferHeightKey: @(evenHeight),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    }];

    if (includeAudio) {
        NSDictionary *audioSettings = @{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVSampleRateKey: @44100,
            AVNumberOfChannelsKey: @1,
            AVEncoderBitRateKey: @128000
        };
        _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        _audioInput.expectsMediaDataInRealTime = YES;
        if ([_writer canAddInput:_audioInput]) {
            [_writer addInput:_audioInput];
        } else {
            _audioInput = nil;
        }
    }

    return self;
}

- (BOOL)startWritingWithError:(NSError **)error {
    if (![_writer startWriting]) {
        if (error) {
            *error = _writer.error ?: [NSError errorWithDomain:@"VentariRecorder" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Writer failed to start."}];
        }
        return NO;
    }
    return YES;
}

- (void)appendVideo:(CVPixelBufferRef)buffer time:(CMTime)time {
    [_lock lock];
    if (_writer.status == AVAssetWriterStatusWriting) {
        if (!_sessionStarted) {
            [_writer startSessionAtSourceTime:time];
            _sessionStarted = YES;
        }
        if (_videoInput.readyForMoreMediaData) {
            [_adaptor appendPixelBuffer:buffer withPresentationTime:time];
        }
    }
    [_lock unlock];
}

- (void)appendAudio:(CMSampleBufferRef)sample {
    [_lock lock];
    if (_sessionStarted && _writer.status == AVAssetWriterStatusWriting && _audioInput.readyForMoreMediaData) {
        [_audioInput appendSampleBuffer:sample];
    }
    [_lock unlock];
}

- (void)finishWithCompletion:(void (^)(NSError *))completion {
    [_lock lock];
    [_videoInput markAsFinished];
    [_audioInput markAsFinished];
    [_lock unlock];

    [_writer finishWritingWithCompletionHandler:^{
        NSError *error = nil;
        if (self->_writer.status == AVAssetWriterStatusFailed) {
            error = self->_writer.error;
        }
        if (completion) completion(error);
    }];
}

@end
