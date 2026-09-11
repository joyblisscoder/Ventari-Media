#import <CoreImage/CoreImage.h>

// Detection runs independently: render the current camera frame with the latest
// available mask, never wait for Vision or queue old camera frames behind it.
@interface BlurProcessor : NSObject
- (CGImageRef)copyFrame:(CVPixelBufferRef)buffer CF_RETURNS_RETAINED;
- (CGImageRef)copyForegroundMask CF_RETURNS_RETAINED;
- (void)reset;
// Overridable for deterministic slow-detector regression tests.
- (CIImage *)personMaskForImage:(CIImage *)image;
@end
