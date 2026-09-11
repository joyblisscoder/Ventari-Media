#import <Foundation/Foundation.h>
#import "Compositor.h"

static CVPixelBufferRef FillBuffer(size_t width, size_t height, uint8_t b, uint8_t g, uint8_t r) {
    CVPixelBufferRef buffer = [[Compositor shared] makeBufferWithWidth:width height:height];
    if (!buffer) return NULL;
    CVPixelBufferLockBaseAddress(buffer, 0);
    uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t i = y * stride + x * 4;
            base[i] = b;
            base[i + 1] = g;
            base[i + 2] = r;
            base[i + 3] = 255;
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

static void ReadPixel(CVPixelBufferRef buffer, size_t x, size_t y, int *b, int *g, int *r) {
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    size_t i = y * stride + x * 4;
    *b = base[i];
    *g = base[i + 1];
    *r = base[i + 2];
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int failures = 0;
        CVPixelBufferRef screen = FillBuffer(320, 180, 0, 0, 255);
        CVPixelBufferRef camera = FillBuffer(64, 64, 255, 0, 0);
        if (!screen || !camera) {
            printf("FAIL: could not allocate pixel buffers\n");
            return 1;
        }

        CVPixelBufferRef withCamera = [[Compositor shared] compositeScreen:screen camera:camera];
        if (CVPixelBufferGetWidth(withCamera) != 320 || CVPixelBufferGetHeight(withCamera) != 180) {
            printf("FAIL: output size should match screen 320x180\n");
            failures++;
        }

        int b, g, r;
        ReadPixel(withCamera, 160, 90, &b, &g, &r);
        if (r < 180 || b > 80) {
            printf("FAIL: center should stay screen-red, got bgr %d %d %d\n", b, g, r);
            failures++;
        }

        CGRect rect = [Compositor circleRectForWidth:320 height:180];
        size_t overlayX = (size_t)CGRectGetMidX(rect);
        size_t overlayY = 180 - (size_t)CGRectGetMidY(rect);
        ReadPixel(withCamera, overlayX, overlayY, &b, &g, &r);
        if (b < 180 || r > 80) {
            printf("FAIL: bottom-right circle should be camera-blue at (%zu,%zu), got bgr %d %d %d\n", overlayX, overlayY, b, g, r);
            failures++;
        }

        CVPixelBufferRef passthrough = [[Compositor shared] compositeScreen:screen camera:NULL];
        ReadPixel(passthrough, 160, 90, &b, &g, &r);
        if (r < 180 || b > 80) {
            printf("FAIL: nil-camera center should stay red, got bgr %d %d %d\n", b, g, r);
            failures++;
        }

        if (failures == 0) {
            printf("PASS: compositor overlay and passthrough\n");
            return 0;
        }
        printf("FAIL: %d assertion(s)\n", failures);
        return 1;
    }
}
