#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "BlurProcessor.h"
#import "Compositor.h"

@interface StalledDetector : BlurProcessor
@property dispatch_semaphore_t entered;
@property dispatch_semaphore_t releaseDetector;
@property (atomic) NSUInteger calls;
@end
@implementation StalledDetector
- (CIImage *)personMaskForImage:(CIImage *)image {
    self.calls++;
    dispatch_semaphore_signal(self.entered);
    dispatch_semaphore_wait(self.releaseDetector, DISPATCH_TIME_FOREVER);
    return nil; // Also exercise detection failure: the live fallback must work.
}
@end

@interface SquareDetector : BlurProcessor
@end
@implementation SquareDetector
- (CIImage *)personMaskForImage:(CIImage *)image {
    return [[CIImage imageWithColor:[CIColor colorWithRed:1 green:1 blue:1]] imageByCroppingToRect:CGRectMake(0, 0, 64, 64)];
}
@end

int main(void) {
    @autoreleasepool {
        StalledDetector *processor = [StalledDetector new];
        processor.entered = dispatch_semaphore_create(0);
        processor.releaseDetector = dispatch_semaphore_create(0);
        dispatch_semaphore_t framesDone = dispatch_semaphore_create(0);
        __block BOOL valid = YES;
        __block double elapsed = 0;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                CFTimeInterval start = CACurrentMediaTime();
                for (int i = 0; i < 30; i++) {
                    @autoreleasepool {
                        CVPixelBufferRef buffer = [[Compositor shared] makeBufferWithWidth:640 height:480];
                        if (!buffer) { valid = NO; break; }
                        CVPixelBufferLockBaseAddress(buffer, 0);
                        // Alternate black/white: displayed pixels must follow the
                        // CURRENT frame even while segmentation remains blocked.
                        memset(CVPixelBufferGetBaseAddress(buffer), i % 2 ? 255 : 0,
                               CVPixelBufferGetBytesPerRow(buffer) * 480);
                        CVPixelBufferUnlockBaseAddress(buffer, 0);
                        CGImageRef frame = [processor copyFrame:buffer];
                        if (!frame || CGImageGetWidth(frame) != 160 || CGImageGetHeight(frame) != 120) valid = NO;
                        if (frame) {
                            unsigned char pixel[4] = {0};
                            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
                            CGContextRef ctx = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
                            CGContextDrawImage(ctx, CGRectMake(0, 0, 1, 1), frame);
                            if ((i % 2 && pixel[0] < 240) || (!(i % 2) && pixel[0] > 15)) valid = NO;
                            CGContextRelease(ctx);
                            CGColorSpaceRelease(space);
                            CGImageRelease(frame);
                        }
                        CVPixelBufferRelease(buffer);
                        if (i == 10) [processor reset]; // Must not queue more work behind stalled detection.
                    }
                }
                elapsed = CACurrentMediaTime() - start;
                dispatch_semaphore_signal(framesDone);
            }
        });
        BOOL entered = dispatch_semaphore_wait(processor.entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        BOOL finished = dispatch_semaphore_wait(framesDone, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        NSUInteger calls = processor.calls;
        dispatch_semaphore_signal(processor.releaseDetector);
        if (!entered || !finished || !valid || calls != 1) {
            fprintf(stderr, "FAIL: rendering blocked, stale pixels, or detector backlog (entered=%d finished=%d pixels=%d calls=%lu)\n", entered, finished, valid, (unsigned long)calls);
            return 1;
        }
        printf("PASS: 30 current frames in %.3fs while detector stalled; one in-flight request across reset\n", elapsed);
        SquareDetector *square = [SquareDetector new];
        CVPixelBufferRef camera = [[Compositor shared] makeBufferWithWidth:640 height:480];
        CGImageRef background = [square copyFrame:camera];
        if (background) CGImageRelease(background);
        CVPixelBufferRelease(camera);
        CGImageRef mask = NULL;
        for (int i = 0; i < 200 && !mask; i++) {
            [NSThread sleepForTimeInterval:0.01];
            mask = [square copyForegroundMask];
        }
        BOOL aligned = mask && CGImageGetWidth(mask) == 320 && CGImageGetHeight(mask) == 240;
        if (mask) CGImageRelease(mask);
        if (!aligned) {
            fprintf(stderr, "FAIL: square detector mask must match 4:3 camera before aspect-fill\n");
            return 1;
        }
        printf("PASS: detector mask normalized to camera aspect ratio\n");
        return 0;
    }
}
