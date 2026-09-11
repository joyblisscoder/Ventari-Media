#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

@interface CaptureEngine : NSObject
@property (nonatomic, copy) void (^onError)(NSError *error);
- (void)startWithDisplay:(SCDisplay *)display
                   width:(NSInteger)width
                  height:(NSInteger)height
      microphoneEnabled:(BOOL)microphoneEnabled
           microphoneID:(NSString *)microphoneID
              outputURL:(NSURL *)outputURL
             completion:(void (^)(NSError *error))completion;
- (void)stopWithCompletion:(void (^)(NSError *error))completion;
- (void)setMicrophoneEnabled:(BOOL)enabled;
@end
