#import <AppKit/AppKit.h>

@interface CountdownOverlay : NSObject
- (void)runOnScreen:(NSScreen *)screen completion:(void (^)(BOOL cancelled))completion;
- (void)cancel;
@end
