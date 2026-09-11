#import <AppKit/AppKit.h>

@interface CountdownOverlay : NSObject
- (void)runOnScreens:(NSArray<NSScreen *> *)screens completion:(void (^)(BOOL cancelled))completion;
- (void)cancel;
@end
