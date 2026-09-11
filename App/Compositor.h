#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>

@interface Compositor : NSObject
+ (instancetype)shared;
- (CVPixelBufferRef)compositeScreen:(CVPixelBufferRef)screen camera:(CVPixelBufferRef)camera;
- (CVPixelBufferRef)makeBufferWithWidth:(size_t)width height:(size_t)height;
+ (CGRect)circleRectForWidth:(size_t)width height:(size_t)height;
@end
