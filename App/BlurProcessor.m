#import "BlurProcessor.h"
#import <Vision/Vision.h>
#import <QuartzCore/QuartzCore.h>

@implementation BlurProcessor {
    CIContext *_context;
    dispatch_queue_t _maskQueue;
    VNGeneratePersonSegmentationRequest *_request;
    id _foregroundMask;
    BOOL _busy;
    NSUInteger _generation;
    CFTimeInterval _lastDetection;
}

- (instancetype)init {
    if ((self = [super init])) {
        _context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates: @NO}];
        _maskQueue = dispatch_queue_create("com.ventari.media.segmentation", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)reset {
    @synchronized (self) {
        _generation++;
        _foregroundMask = nil;
        _lastDetection = 0;
        // An in-flight request still owns the single detection slot until done.
    }
}

- (CIImage *)personMaskForImage:(CIImage *)image {
    if (!_request) {
        _request = [VNGeneratePersonSegmentationRequest new];
        _request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelBalanced;
        _request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    }
    CGFloat scale = MIN(1.0, 384.0 / MAX(image.extent.size.width, image.extent.size.height));
    CIImage *small = [image imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:small options:@{}];
    if (![handler performRequests:@[_request] error:nil]) return nil;
    VNPixelBufferObservation *observation = _request.results.firstObject;
    return observation ? [CIImage imageWithCVPixelBuffer:observation.pixelBuffer] : nil;
}

- (CGImageRef)copyFrame:(CVPixelBufferRef)buffer {
    if (!buffer) return NULL;
    CIImage *person = [CIImage imageWithCVPixelBuffer:buffer];
    BOOL detect = NO;
    NSUInteger generation;
    @synchronized (self) {
        generation = _generation;
        CFTimeInterval now = CACurrentMediaTime();
        // At most 15 masks/sec and one request in flight, including slow hardware.
        if (!_busy && now - _lastDetection >= 1.0 / 15.0) {
            _busy = YES;
            _lastDetection = now;
            detect = YES;
        }
    }
    if (detect) {
        dispatch_async(_maskQueue, ^{
            @autoreleasepool {
                CIImage *result = [self personMaskForImage:person];
                id alphaMask = nil;
                if (result) {
                    // Vision's mask dimensions need not match the camera aspect
                    // ratio. Normalize BEFORE the preview's aspect-fill crop.
                    CGFloat maskScale = MIN(1.0, 320.0 / MAX(person.extent.size.width, person.extent.size.height));
                    CGRect maskRect = CGRectMake(0, 0, person.extent.size.width * maskScale,
                                                  person.extent.size.height * maskScale);
                    result = [result imageByApplyingTransform:CGAffineTransformMakeScale(
                        maskRect.size.width / result.extent.size.width,
                        maskRect.size.height / result.extent.size.height)];
                    // A small margin protects facial/hair edges as the live feed
                    // moves between mask updates, with a soft transition.
                    result = [result imageByApplyingFilter:@"CIMorphologyMaximum" withInputParameters:@{kCIInputRadiusKey: @1.0}];
                    result = [[result imageByApplyingGaussianBlurWithSigma:0.75] imageByCroppingToRect:maskRect];
                    // CALayer masks use alpha, whereas Vision returns luminance.
                    result = [result imageByApplyingFilter:@"CIColorMatrix" withInputParameters:@{
                        @"inputRVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
                        @"inputGVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
                        @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
                        @"inputAVector": [CIVector vectorWithX:1 Y:0 Z:0 W:0],
                        @"inputBiasVector": [CIVector vectorWithX:1 Y:1 Z:1 W:0]
                    }];
                    result = [result imageByApplyingTransform:CGAffineTransformMake(-1, 0, 0, 1, result.extent.size.width, 0)];
                    alphaMask = CFBridgingRelease([self->_context createCGImage:result fromRect:result.extent]);
                }
                @synchronized (self) {
                    if (generation == self->_generation) self->_foregroundMask = alphaMask;
                    self->_busy = NO;
                }
            }
        });
    }

    const CGFloat down = MIN(1.0, 160.0 / MAX(person.extent.size.width, person.extent.size.height));
    CIImage *tiny = [person imageByApplyingTransform:CGAffineTransformMakeScale(down, down)];
    CIImage *blurred = [[tiny imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:9.0];
    blurred = [blurred imageByCroppingToRect:tiny.extent];
    // Only the background takes this path. The face stays in the hardware
    // preview layer, with the cached alpha mask applied by Core Animation.
    CIImage *output = blurred;
    CGAffineTransform flip = CGAffineTransformMake(-1, 0, 0, 1, tiny.extent.size.width, 0);
    output = [output imageByApplyingTransform:flip];
    return [_context createCGImage:output fromRect:tiny.extent];
}

- (CGImageRef)copyForegroundMask {
    @synchronized (self) {
        return _foregroundMask ? CGImageRetain((__bridge CGImageRef)_foregroundMask) : NULL;
    }
}
@end
