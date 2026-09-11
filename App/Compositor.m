#import "Compositor.h"
#import <CoreImage/CoreImage.h>

@implementation Compositor {
    CIContext *_context;
}

+ (instancetype)shared {
    static Compositor *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [Compositor new];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        _context = [CIContext contextWithOptions:@{
            kCIContextWorkingColorSpace: (__bridge id)srgb,
            kCIContextOutputColorSpace: (__bridge id)srgb
        }];
        CGColorSpaceRelease(srgb);
    }
    return self;
}

+ (CGRect)circleRectForWidth:(size_t)width height:(size_t)height {
    CGFloat shortSide = (CGFloat)MIN(width, height);
    CGFloat diameter = shortSide * 0.22;
    CGFloat padding = shortSide * 0.035;
    return CGRectMake((CGFloat)width - padding - diameter, padding, diameter, diameter);
}

- (CVPixelBufferRef)makeBufferWithWidth:(size_t)width height:(size_t)height {
    NSDictionary *attrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    CVPixelBufferRef buffer = NULL;
    CVReturn status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)attrs,
        &buffer
    );
    if (status != kCVReturnSuccess) return NULL;
    return buffer;
}

- (CVPixelBufferRef)compositeScreen:(CVPixelBufferRef)screen camera:(CVPixelBufferRef)camera {
    if (!screen) return NULL;
    size_t width = CVPixelBufferGetWidth(screen);
    size_t height = CVPixelBufferGetHeight(screen);
    CVPixelBufferRef output = [self makeBufferWithWidth:width height:height];
    if (!output) {
        CVPixelBufferRetain(screen);
        return screen;
    }

    CIImage *result = [CIImage imageWithCVPixelBuffer:screen];
    if (camera) {
        CIImage *overlay = [self circleOverlayFromCamera:[CIImage imageWithCVPixelBuffer:camera]
                                                   width:width
                                                  height:height];
        result = [overlay imageByCompositingOverImage:result];
    }
    result = [result imageByCroppingToRect:CGRectMake(0, 0, width, height)];
    [_context render:result toCVPixelBuffer:output];
    return output;
}

- (CIImage *)circleOverlayFromCamera:(CIImage *)camera width:(size_t)width height:(size_t)height {
    CGRect rect = [Compositor circleRectForWidth:width height:height];
    CGFloat diameter = CGRectGetWidth(rect);
    CGRect extent = camera.extent;
    CGFloat side = MIN(CGRectGetWidth(extent), CGRectGetHeight(extent));
    CGRect crop = CGRectMake(CGRectGetMidX(extent) - side / 2.0,
                             CGRectGetMidY(extent) - side / 2.0,
                             side,
                             side);
    CIImage *cam = [camera imageByCroppingToRect:crop];
    CGFloat scale = diameter / side;
    cam = [cam imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    cam = [cam imageByApplyingTransform:CGAffineTransformMakeTranslation(-cam.extent.origin.x, -cam.extent.origin.y)];
    cam = [cam imageByApplyingTransform:CGAffineTransformMakeScale(-1, 1)];
    cam = [cam imageByApplyingTransform:CGAffineTransformMakeTranslation(-cam.extent.origin.x, -cam.extent.origin.y)];
    cam = [cam imageByApplyingTransform:CGAffineTransformMakeTranslation(rect.origin.x, rect.origin.y)];

    CIVector *center = [CIVector vectorWithX:CGRectGetMidX(rect) Y:CGRectGetMidY(rect)];
    CIFilter *maskFilter = [CIFilter filterWithName:@"CIRadialGradient"];
    [maskFilter setValue:center forKey:kCIInputCenterKey];
    [maskFilter setValue:@(diameter / 2.0 - 1.0) forKey:@"inputRadius0"];
    [maskFilter setValue:@(diameter / 2.0) forKey:@"inputRadius1"];
    [maskFilter setValue:[CIColor colorWithRed:1 green:1 blue:1 alpha:1] forKey:@"inputColor0"];
    [maskFilter setValue:[CIColor colorWithRed:1 green:1 blue:1 alpha:0] forKey:@"inputColor1"];
    CIImage *mask = [[maskFilter outputImage] imageByCroppingToRect:rect];

    CIFilter *ringFilter = [CIFilter filterWithName:@"CIRadialGradient"];
    [ringFilter setValue:center forKey:kCIInputCenterKey];
    [ringFilter setValue:@(MAX(0, diameter / 2.0 - 4.0)) forKey:@"inputRadius0"];
    [ringFilter setValue:@(diameter / 2.0) forKey:@"inputRadius1"];
    [ringFilter setValue:[CIColor colorWithRed:1 green:1 blue:1 alpha:0] forKey:@"inputColor0"];
    [ringFilter setValue:[CIColor colorWithRed:1 green:1 blue:1 alpha:0.95] forKey:@"inputColor1"];
    CIImage *ring = [[ringFilter outputImage] imageByCroppingToRect:rect];

    CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithAlphaMask"];
    [blend setValue:cam forKey:kCIInputImageKey];
    [blend setValue:mask forKey:kCIInputMaskImageKey];
    CIImage *masked = [blend outputImage] ?: cam;
    return [masked imageByCompositingOverImage:ring];
}

@end
