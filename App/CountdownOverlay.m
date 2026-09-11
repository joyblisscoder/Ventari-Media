#import "CountdownOverlay.h"
#import "Brand.h"

@interface CountdownOverlay ()
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, copy) void (^completion)(BOOL cancelled);
@property (nonatomic, assign) NSInteger remaining;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation CountdownOverlay

- (void)runOnScreen:(NSScreen *)screen completion:(void (^)(BOOL))completion {
    [self teardownSilent];
    self.completion = completion;
    self.remaining = 3;

    NSRect frame = screen.frame;
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskBorderless
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.opaque = NO;
    self.window.backgroundColor = [VRBackgroundColor() colorWithAlphaComponent:0.62];
    self.window.level = NSModalPanelWindowLevel;
    self.window.hidesOnDeactivate = NO;
    self.window.releasedWhenClosed = NO;
    self.window.sharingType = NSWindowSharingNone;
    self.window.ignoresMouseEvents = YES;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
        | NSWindowCollectionBehaviorFullScreenAuxiliary
        | NSWindowCollectionBehaviorTransient;

    self.label = [NSTextField labelWithString:@"3"];
    self.label.font = [NSFont monospacedDigitSystemFontOfSize:220 weight:NSFontWeightBold];
    self.label.textColor = VRGoldColor();
    self.label.alignment = NSTextAlignmentCenter;
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:self.label];
    [NSLayoutConstraint activateConstraints:@[
        [self.label.centerXAnchor constraintEqualToAnchor:self.window.contentView.centerXAnchor],
        [self.label.centerYAnchor constraintEqualToAnchor:self.window.contentView.centerYAnchor]
    ]];

    [self.window setFrame:frame display:YES];
    [self.window orderFrontRegardless];
    [self tick];
}

- (void)tick {
    if (self.remaining <= 0) {
        void (^done)(BOOL) = self.completion;
        [self teardownSilent];
        if (done) done(NO);
        return;
    }
    self.label.stringValue = [NSString stringWithFormat:@"%ld", (long)self.remaining];
    self.remaining -= 1;
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)cancel {
    void (^done)(BOOL) = self.completion;
    [self teardownSilent];
    if (done) done(YES);
}

- (void)teardownSilent {
    [self.timer invalidate];
    self.timer = nil;
    self.completion = nil;
    [self.window orderOut:nil];
    self.window = nil;
    self.label = nil;
}

@end
