#import "Brand.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

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

NSNotificationName const VRMediaAppearanceChangedNotification = @"VRMediaAppearanceChangedNotification";
static NSString * const VRGradientStartKey = @"VentariMediaGradientStart";
static NSString * const VRGradientEndKey = @"VentariMediaGradientEnd";
static NSString * const VRCameraRingKey = @"VentariMediaCameraRing";

static NSColor *VRStoredColor(NSString *key, NSColor *fallback) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    if (![value isKindOfClass:NSArray.class] || [value count] != 3) return fallback;
    for (id component in value) {
        if (![component isKindOfClass:NSNumber.class] || !([component doubleValue] >= 0 && [component doubleValue] <= 1)) return fallback;
    }
    return [NSColor colorWithSRGBRed:[value[0] doubleValue] green:[value[1] doubleValue] blue:[value[2] doubleValue] alpha:1];
}

NSColor *VRGradientStartColor(void) { return VRStoredColor(VRGradientStartKey, VROrangeColor()); }
NSColor *VRGradientEndColor(void) { return VRStoredColor(VRGradientEndKey, VRGoldColor()); }
NSColor *VRCameraRingColor(void) { return VRStoredColor(VRCameraRingKey, VRGoldColor()); }

static void VRStoreColor(NSString *key, NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (rgb) [NSUserDefaults.standardUserDefaults setObject:@[@(rgb.redComponent), @(rgb.greenComponent), @(rgb.blueComponent)] forKey:key];
}

void VRSetAppearanceColors(NSColor *start, NSColor *end, NSColor *ring) {
    VRStoreColor(VRGradientStartKey, start);
    VRStoreColor(VRGradientEndKey, end);
    VRStoreColor(VRCameraRingKey, ring);
    [NSNotificationCenter.defaultCenter postNotificationName:VRMediaAppearanceChangedNotification object:nil];
}

void VRResetAppearanceColors(void) {
    for (NSString *key in @[VRGradientStartKey, VRGradientEndKey, VRCameraRingKey]) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:VRMediaAppearanceChangedNotification object:nil];
}

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

@interface VROrangeGradientView : NSView
@property (nonatomic, strong) CAGradientLayer *gradient;
@end

@implementation VROrangeGradientView
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.locations = @[@0, @0.43, @1];
        gradient.startPoint = CGPointMake(0.0, 1.0);
        gradient.endPoint = CGPointMake(1.0, 0.0);
        self.layer = gradient;
        self.gradient = gradient;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAppearance) name:VRMediaAppearanceChangedNotification object:nil];
        [self updateAppearance];
    }
    return self;
}

- (void)updateAppearance {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.gradient.colors = @[(__bridge id)VRGradientStartColor().CGColor,
                             (__bridge id)VRGradientEndColor().CGColor,
                             (__bridge id)VRBackgroundColor().CGColor];
    [CATransaction commit];
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
