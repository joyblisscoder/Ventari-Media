#import <AppKit/AppKit.h>

NSColor *VRBackgroundColor(void);
NSColor *VRSurfaceColor(void);
NSColor *VRGoldColor(void);
NSColor *VROrangeColor(void);
NSColor *VRTealColor(void);
NSColor *VRZincColor(void);
NSColor *VRMutedColor(void);
NSColor *VRBorderColor(void);
NSColor *VRDangerColor(void);
NSColor *VRGradientStartColor(void);
NSColor *VRGradientEndColor(void);
NSColor *VRCameraRingColor(void);
void VRSetAppearanceColors(NSColor *start, NSColor *end, NSColor *ring);
void VRResetAppearanceColors(void);
extern NSNotificationName const VRMediaAppearanceChangedNotification;

NSFont *VRLogoFont(CGFloat size);
NSFont *VRHeadingFont(CGFloat size);
NSFont *VRBodyFont(CGFloat size);
NSFont *VRMonoFont(CGFloat size);

void VRRegisterBrandFonts(void);
NSImage *VRLogoImage(void);
NSURL *VRSiteURL(void);
void VROpenSite(void);
extern NSNotificationName const VRMediaPauseIdleEffectsNotification;
extern NSNotificationName const VRMediaResumeIdleEffectsNotification;

void VRStyleWindow(NSWindow *window);
void VRInstallOrangeGradient(NSView *view);
void VRStylePopup(NSPopUpButton *popup);
NSTextField *VRLabel(NSString *text, NSFont *font, NSColor *color);
