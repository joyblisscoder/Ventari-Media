#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

@interface MovieWriter : NSObject
- (instancetype)initWithURL:(NSURL *)url
                      width:(NSInteger)width
                     height:(NSInteger)height
               includeAudio:(BOOL)includeAudio
                      error:(NSError **)error;
- (BOOL)startWritingWithError:(NSError **)error;
- (void)appendVideo:(CVPixelBufferRef)buffer time:(CMTime)time;
- (void)appendAudio:(CMSampleBufferRef)sample;
- (void)finishWithCompletion:(void (^)(NSError *error))completion;
@end
