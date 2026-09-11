#import "Brand.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSColor *Hex(NSUInteger hex, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:((hex >> 16) & 0xff) / 255.0
                               green:((hex >> 8) & 0xff) / 255.0
                                blue:(hex & 0xff) / 255.0
                               alpha:alpha];
}

NSColor *VRBackgroundColor(void) { return Hex(0x080808, 1); }
NSColor *VRSurfaceColor(void) { return Hex(0x0f0f0f, 1); }
NSColor *VRGoldColor(void) { return Hex(0xffaa00, 1); }
NSColor *VROrangeColor(void) { return Hex(0xff5000, 1); }
NSColor *VRTealColor(void) { return Hex(0x7cc4ba, 1); }
NSColor *VRZincColor(void) { return Hex(0xf4f4f5, 1); }
NSColor *VRMutedColor(void) { return Hex(0x71717a, 1); }
NSColor *VRBorderColor(void) { return Hex(0xffffff, 0.07); }
NSColor *VRDangerColor(void) { return Hex(0xef4444, 1); }

void VRRegisterBrandFonts(void) {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Horizon" withExtension:@"otf"];
    if (url) {
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
    }
}

NSFont *VRLogoFont(CGFloat size) {
    NSFont *font = [NSFont fontWithName:@"Horizon" size:size];
    if (!font) font = [NSFont fontWithName:@"Horizon-Regular" size:size];
    return font ?: [NSFont systemFontOfSize:size weight:NSFontWeightLight];
}

NSFont *VRHeadingFont(CGFloat size) {
    return [NSFont systemFontOfSize:size weight:NSFontWeightSemibold];
}

NSFont *VRBodyFont(CGFloat size) {
    return [NSFont systemFontOfSize:size weight:NSFontWeightRegular];
}

NSFont *VRMonoFont(CGFloat size) {
    return [NSFont monospacedDigitSystemFontOfSize:size weight:NSFontWeightMedium];
}

NSImage *VRLogoImage(void) {
    NSImage *image = [NSImage imageNamed:@"Logo"];
    if (!image) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"Logo" withExtension:@"png"];
        if (url) image = [[NSImage alloc] initWithContentsOfURL:url];
    }
    return image;
}

NSURL *VRSiteURL(void) {
    return [NSURL URLWithString:@"https://ventari.media"];
}

void VROpenSite(void) {
    NSURL *url = VRSiteURL();
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

NSNotificationName const VRMediaPauseIdleEffectsNotification = @"VRMediaPauseIdleEffectsNotification";
NSNotificationName const VRMediaResumeIdleEffectsNotification = @"VRMediaResumeIdleEffectsNotification";

static id VRColorStop(NSUInteger hex) {
    return (__bridge id)Hex(hex, 1).CGColor;
}

static NSValue *VRPoint(CGFloat x, CGFloat y) {
    CGPoint p = CGPointMake(x, y);
    return [NSValue value:&p withObjCType:@encode(CGPoint)];
}

@interface VROrangeGradientView : NSView
@property (nonatomic, strong) CAGradientLayer *gradient;
@end

@implementation VROrangeGradientView
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        CAGradientLayer *gradient = [CAGradientLayer layer];
        // Evenly spaced orange → gold → dark so every edge is a fade, never a hard band.
        gradient.colors = @[
            VRColorStop(0xff5000),
            VRColorStop(0xff5c0a),
            VRColorStop(0xff6a12),
            VRColorStop(0xff7a18),
            VRColorStop(0xff8c14),
            VRColorStop(0xff9c0a),
            VRColorStop(0xffaa00),
            VRColorStop(0xe09008),
            VRColorStop(0xc07010),
            VRColorStop(0x9a5010),
            VRColorStop(0x743810),
            VRColorStop(0x4e2410),
            VRColorStop(0x2e1408),
            VRColorStop(0x180a04),
            VRColorStop(0x0c0602)
        ];
        NSMutableArray *locations = [NSMutableArray array];
        NSUInteger count = 15;
        for (NSUInteger i = 0; i < count; i++) {
            [locations addObject:@((CGFloat)i / (CGFloat)(count - 1))];
        }
        gradient.locations = locations;
        gradient.startPoint = CGPointMake(0.0, 1.0);
        gradient.endPoint = CGPointMake(1.0, 0.0);
        self.layer = gradient;
        self.gradient = gradient;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseIdle) name:VRMediaPauseIdleEffectsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeIdle) name:VRMediaResumeIdleEffectsNotification object:nil];
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        [self resumeIdle];
    } else {
        [self pauseIdle];
    }
}

- (void)pauseIdle {
    [self.gradient removeAllAnimations];
}

- (void)resumeIdle {
    [self.gradient removeAllAnimations];
    if (!self.window) return;
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;

    NSMutableArray *starts = [NSMutableArray array];
    NSMutableArray *ends = [NSMutableArray array];
    const NSInteger steps = 16;
    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat a = ((CGFloat)i / (CGFloat)steps) * (CGFloat)M_PI * 2.0;
        [starts addObject:VRPoint(0.5 + 0.48 * cos(a), 0.5 + 0.48 * sin(a))];
        [ends addObject:VRPoint(0.5 - 0.48 * cos(a), 0.5 - 0.48 * sin(a))];
    }

    CAKeyframeAnimation *start = [CAKeyframeAnimation animationWithKeyPath:@"startPoint"];
    start.values = starts;
    start.duration = 28.0;
    start.repeatCount = HUGE_VALF;
    start.calculationMode = kCAAnimationPaced;
    start.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    CAKeyframeAnimation *end = [CAKeyframeAnimation animationWithKeyPath:@"endPoint"];
    end.values = ends;
    end.duration = 28.0;
    end.repeatCount = HUGE_VALF;
    end.calculationMode = kCAAnimationPaced;
    end.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    [self.gradient addAnimation:start forKey:@"vr.driftStart"];
    [self.gradient addAnimation:end forKey:@"vr.driftEnd"];
}

- (void)layout {
    [super layout];
    self.layer.frame = self.bounds;
}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

void VRInstallOrangeGradient(NSView *view) {
    for (NSView *sub in view.subviews) {
        if ([sub isKindOfClass:[VROrangeGradientView class]]) {
            sub.frame = view.bounds;
            return;
        }
    }
    VROrangeGradientView *backdrop = [[VROrangeGradientView alloc] initWithFrame:view.bounds];
    backdrop.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [view addSubview:backdrop positioned:NSWindowBelow relativeTo:nil];
}

void VRStyleWindow(NSWindow *window) {
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.backgroundColor = Hex(0xff5000, 1);
    window.contentView.wantsLayer = YES;
    VRInstallOrangeGradient(window.contentView);
}

void VRStylePopup(NSPopUpButton *popup) {
    popup.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    popup.bezelStyle = NSBezelStyleRegularSquare;
    popup.controlSize = NSControlSizeRegular;
}

NSTextField *VRLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *field = [NSTextField labelWithString:text];
    field.font = font;
    field.textColor = color;
    field.backgroundColor = NSColor.clearColor;
    field.drawsBackground = NO;
    field.selectable = YES;
    return field;
}
