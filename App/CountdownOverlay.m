#import "CountdownOverlay.h"
#import "Brand.h"

@interface CountdownOverlay ()
@property (nonatomic, copy) NSArray<NSWindow *> *windows;
@property (nonatomic, copy) NSArray<NSTextField *> *labels;
@property (nonatomic, copy) void (^completion)(BOOL cancelled);
@property (nonatomic, assign) NSInteger remaining;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation CountdownOverlay

- (void)runOnScreens:(NSArray<NSScreen *> *)screens completion:(void (^)(BOOL))completion {
    [self teardownSilent];
    self.completion = completion;
    self.remaining = 3;

    NSMutableArray<NSWindow *> *windows = [NSMutableArray array];
    NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
    NSArray<NSScreen *> *targets = screens.count ? screens : [NSScreen screens];
    for (NSScreen *screen in targets) {
        NSWindow *window = [[NSWindow alloc] initWithContentRect:screen.frame
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.opaque = NO;
        window.backgroundColor = [VRBackgroundColor() colorWithAlphaComponent:0.62];
        window.level = NSModalPanelWindowLevel;
        window.hidesOnDeactivate = NO;
        window.releasedWhenClosed = NO;
        window.sharingType = NSWindowSharingNone;
        window.ignoresMouseEvents = YES;
        window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
            | NSWindowCollectionBehaviorFullScreenAuxiliary
            | NSWindowCollectionBehaviorTransient;

        NSTextField *label = [NSTextField labelWithString:@"3"];
        label.font = [NSFont monospacedDigitSystemFontOfSize:220 weight:NSFontWeightBold];
        label.textColor = VRGoldColor();
        label.alignment = NSTextAlignmentCenter;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [window.contentView addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:window.contentView.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:window.contentView.centerYAnchor]
        ]];
        [window setFrame:screen.frame display:YES];
        [window orderFrontRegardless];
        [windows addObject:window];
        [labels addObject:label];
    }
    self.windows = windows;
    self.labels = labels;
    [self tick];
}

- (void)tick {
    if (self.remaining <= 0) {
        void (^done)(BOOL) = self.completion;
        [self teardownSilent];
        if (done) done(NO);
        return;
    }
    NSString *text = [NSString stringWithFormat:@"%ld", (long)self.remaining];
    for (NSTextField *label in self.labels) {
        label.stringValue = text;
    }
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
    for (NSWindow *window in self.windows) {
        [window orderOut:nil];
    }
    self.windows = nil;
    self.labels = nil;
}

@end
