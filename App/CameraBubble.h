#import <AppKit/AppKit.h>

@interface CameraBubble : NSObject
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readonly) BOOL visible;
- (void)show;
- (void)hide;
- (void)pausePreview;
- (void)resumePreview;
- (void)moveOntoScreen:(NSScreen *)screen ifNeeded:(BOOL)ifNeeded;
@end
