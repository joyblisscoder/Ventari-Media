#import "AppDelegate.h"
#import "Brand.h"
#import "Recorder.h"
#import "SaveSheet.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) Recorder *recorder;
@property (nonatomic, strong) NSPopUpButton *screenPopup;
@property (nonatomic, strong) NSSwitch *cameraSwitch;
@property (nonatomic, strong) NSSwitch *micSwitch;
@property (nonatomic, strong) NSPopUpButton *micPopup;
@property (nonatomic, strong) NSButton *recordButton;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *settingsButton;
@property (nonatomic, strong) SaveSheet *saveSheet;
@property (nonatomic, assign) BOOL updatingUI;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    VRRegisterBrandFonts();

    self.recorder = [Recorder new];
    __weak typeof(self) weakSelf = self;
    self.recorder.onChange = ^{
        [weakSelf reloadUI];
    };
    self.recorder.onError = ^(NSString *message, BOOL needsScreenPermission) {
        [weakSelf showError:message needsScreenPermission:needsScreenPermission];
    };
    self.recorder.onAskSaveName = ^(NSString *suggested, void (^respond)(NSString *name)) {
        [weakSelf askForName:suggested respond:respond];
    };

    NSRect frame = NSMakeRect(0, 0, 420, 520);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Ventari Media";
    self.window.releasedWhenClosed = NO;
    self.window.restorable = NO;
    self.window.titleVisibility = NSWindowTitleHidden;
    VRStyleWindow(self.window);

    NSView *content = self.window.contentView;
    VRInstallOrangeGradient(content);
    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.edgeInsets = NSEdgeInsetsMake(52, 22, 22, 22);
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]
    ]];

    NSStackView *header = [NSStackView new];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 12;

    NSButton *logo = [NSButton new];
    logo.image = VRLogoImage();
    logo.imagePosition = NSImageOnly;
    logo.imageScaling = NSImageScaleProportionallyUpOrDown;
    logo.bordered = NO;
    logo.bezelStyle = NSBezelStyleRegularSquare;
    logo.toolTip = @"ventari.media";
    logo.target = self;
    logo.action = @selector(openSite:);
    [logo.widthAnchor constraintEqualToConstant:40].active = YES;
    [logo.heightAnchor constraintEqualToConstant:40].active = YES;

    NSStackView *titles = [NSStackView new];
    titles.orientation = NSUserInterfaceLayoutOrientationVertical;
    titles.alignment = NSLayoutAttributeLeading;
    titles.spacing = 2;
    NSTextField *wordmark = VRLabel(@"Ventari Media", VRLogoFont(18), VRZincColor());
    NSTextField *product = VRLabel(@"Freedom to screen recording!", VRBodyFont(12), VRMutedColor());
    product.maximumNumberOfLines = 2;
    [titles addArrangedSubview:wordmark];
    [titles addArrangedSubview:product];

    [header addArrangedSubview:logo];
    [header addArrangedSubview:titles];
    [stack addArrangedSubview:header];

    NSBox *rule = [NSBox new];
    rule.boxType = NSBoxSeparator;
    rule.borderColor = VRBorderColor();
    [rule.heightAnchor constraintEqualToConstant:1].active = YES;
    [rule.widthAnchor constraintEqualToConstant:356].active = YES;
    [stack addArrangedSubview:rule];

    [stack addArrangedSubview:VRLabel(@"Screen", VRHeadingFont(12), VRMutedColor())];
    self.screenPopup = [NSPopUpButton new];
    self.screenPopup.target = self;
    self.screenPopup.action = @selector(screenChanged:);
    VRStylePopup(self.screenPopup);
    [self.screenPopup.widthAnchor constraintEqualToConstant:356].active = YES;
    [stack addArrangedSubview:self.screenPopup];

    self.cameraSwitch = [NSSwitch new];
    self.cameraSwitch.target = self;
    self.cameraSwitch.action = @selector(cameraChanged:);
    [stack addArrangedSubview:[self rowWithTitle:@"Camera overlay" accessory:self.cameraSwitch]];

    self.micSwitch = [NSSwitch new];
    self.micSwitch.target = self;
    self.micSwitch.action = @selector(micChanged:);
    [stack addArrangedSubview:[self rowWithTitle:@"Microphone" accessory:self.micSwitch]];

    self.micPopup = [NSPopUpButton new];
    self.micPopup.target = self;
    self.micPopup.action = @selector(micDeviceChanged:);
    VRStylePopup(self.micPopup);
    [self.micPopup.widthAnchor constraintEqualToConstant:356].active = YES;
    [stack addArrangedSubview:self.micPopup];

    self.recordButton = [NSButton new];
    self.recordButton.title = @"Record";
    self.recordButton.bordered = NO;
    self.recordButton.wantsLayer = YES;
    self.recordButton.layer.cornerRadius = 8;
    self.recordButton.layer.backgroundColor = VRGoldColor().CGColor;
    self.recordButton.font = VRHeadingFont(14);
    self.recordButton.contentTintColor = VRBackgroundColor();
    self.recordButton.keyEquivalent = @"\r";
    self.recordButton.target = self;
    self.recordButton.action = @selector(toggleRecord:);
    [self.recordButton.heightAnchor constraintEqualToConstant:36].active = YES;
    [self.recordButton.widthAnchor constraintEqualToConstant:356].active = YES;
    [stack addArrangedSubview:self.recordButton];

    self.statusLabel = VRLabel(@"Ready · Desktop", VRBodyFont(12), VRMutedColor());
    [stack addArrangedSubview:self.statusLabel];

    self.settingsButton = [NSButton buttonWithTitle:@"Open Screen Recording Settings" target:self action:@selector(openSettings:)];
    self.settingsButton.bezelStyle = NSBezelStyleRounded;
    [self.settingsButton.widthAnchor constraintEqualToConstant:356].active = YES;
    [stack addArrangedSubview:self.settingsButton];

    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    self.window.sharingType = NSWindowSharingNone;
    [NSApp activateIgnoringOtherApps:YES];
    self.recorder.controlWindow = self.window;
    [self.recorder bootstrap];
    [self reloadUI];
}

- (NSView *)rowWithTitle:(NSString *)title accessory:(NSView *)accessory {
    NSStackView *row = [NSStackView new];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    NSTextField *label = VRLabel(title, VRBodyFont(13), VRZincColor());
    [row addArrangedSubview:label];
    [row addArrangedSubview:accessory];
    [row.widthAnchor constraintEqualToConstant:356].active = YES;
    return row;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self.recorder refreshDevices];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)styleRecordButtonGold {
    self.recordButton.layer.backgroundColor = VRGoldColor().CGColor;
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:self.recordButton.title attributes:@{
        NSForegroundColorAttributeName: VRBackgroundColor(),
        NSFontAttributeName: VRHeadingFont(14)
    }];
    self.recordButton.attributedTitle = title;
}

- (void)styleRecordButtonStop {
    self.recordButton.layer.backgroundColor = VRDangerColor().CGColor;
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:self.recordButton.title attributes:@{
        NSForegroundColorAttributeName: VRZincColor(),
        NSFontAttributeName: VRHeadingFont(14)
    }];
    self.recordButton.attributedTitle = title;
}

- (void)reloadUI {
    self.updatingUI = YES;

    [self.screenPopup removeAllItems];
    NSInteger selectedIndex = 0;
    if (self.recorder.displays.count == 0) {
        [self.screenPopup addItemWithTitle:@"No displays found"];
    } else {
        for (NSInteger i = 0; i < (NSInteger)self.recorder.displays.count; i++) {
            DisplayInfo *info = self.recorder.displays[i];
            [self.screenPopup addItemWithTitle:info.menuTitle];
            self.screenPopup.lastItem.representedObject = @(info.displayID);
            if (info.displayID == self.recorder.selectedDisplayID) {
                selectedIndex = i;
            }
        }
        [self.screenPopup selectItemAtIndex:selectedIndex];
    }

    [self.micPopup removeAllItems];
    NSInteger micIndex = 0;
    for (NSInteger i = 0; i < (NSInteger)self.recorder.microphones.count; i++) {
        AVCaptureDevice *mic = self.recorder.microphones[i];
        [self.micPopup addItemWithTitle:mic.localizedName];
        self.micPopup.lastItem.representedObject = mic.uniqueID;
        if ([mic.uniqueID isEqualToString:self.recorder.selectedMicrophoneID]) {
            micIndex = i;
        }
    }
    if (self.recorder.microphones.count > 0) {
        [self.micPopup selectItemAtIndex:micIndex];
    }

    self.cameraSwitch.state = self.recorder.cameraEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.micSwitch.state = self.recorder.microphoneEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.screenPopup.enabled = !self.recorder.recording && !self.recorder.countingDown && self.recorder.displays.count > 0;
    self.micPopup.enabled = !self.recorder.recording && self.recorder.microphoneEnabled && self.recorder.microphones.count > 0;
    self.micPopup.alphaValue = self.recorder.microphoneEnabled ? 1.0 : 0.45;

    if (self.recorder.countingDown) {
        self.recordButton.title = @"Cancel";
        [self styleRecordButtonStop];
        self.statusLabel.stringValue = @"Countdown on the selected screen";
        self.statusLabel.textColor = VRMutedColor();
        self.window.level = NSFloatingWindowLevel;
    } else if (self.recorder.recording) {
        self.recordButton.title = @"Stop";
        [self styleRecordButtonStop];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Recording  %@", self.recorder.elapsedLabel];
        self.statusLabel.font = VRMonoFont(12);
        self.statusLabel.textColor = VRDangerColor();
        self.window.level = NSFloatingWindowLevel;
    } else {
        self.recordButton.title = @"Record";
        [self styleRecordButtonGold];
        self.window.level = NSNormalWindowLevel;
        self.statusLabel.font = VRBodyFont(12);
        self.statusLabel.textColor = VRMutedColor();
        if (self.recorder.lastSavedURL) {
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Saved  %@", self.recorder.lastSavedURL.lastPathComponent];
        } else if (self.recorder.displays.count == 0) {
            self.statusLabel.stringValue = @"No displays found.";
        } else {
            self.statusLabel.stringValue = @"Ready · Desktop";
        }
    }

    self.settingsButton.hidden = self.recorder.displays.count > 0;
    self.recordButton.enabled = YES;
    self.updatingUI = NO;
}

- (void)screenChanged:(id)sender {
    if (self.updatingUI) return;
    NSNumber *value = self.screenPopup.selectedItem.representedObject;
    if (value) self.recorder.selectedDisplayID = value.unsignedIntValue;
}

- (void)cameraChanged:(id)sender {
    if (self.updatingUI) return;
    [self.recorder handleCameraToggle:self.cameraSwitch.state == NSControlStateValueOn];
}

- (void)micChanged:(id)sender {
    if (self.updatingUI) return;
    [self.recorder handleMicrophoneToggle:self.micSwitch.state == NSControlStateValueOn];
    [self reloadUI];
}

- (void)micDeviceChanged:(id)sender {
    if (self.updatingUI) return;
    NSString *uniqueID = self.micPopup.selectedItem.representedObject;
    if (uniqueID) self.recorder.selectedMicrophoneID = uniqueID;
}

- (void)toggleRecord:(id)sender {
    if (self.recorder.recording || self.recorder.countingDown) {
        [self.recorder stop];
    } else {
        [self.recorder start];
    }
}

- (void)openSite:(id)sender {
    VROpenSite();
}

- (void)openSettings:(id)sender {
    [self.recorder requestScreenAccess];
    [self.recorder openScreenRecordingSettings];
}

- (void)askForName:(NSString *)suggested respond:(void (^)(NSString *name))respond {
    [self.window makeKeyAndOrderFront:nil];
    self.saveSheet = [SaveSheet new];
    [self.saveSheet beginOnWindow:self.window suggestedName:suggested completion:^(NSString *name) {
        respond(name);
    }];
}

- (void)showError:(NSString *)message needsScreenPermission:(BOOL)needsScreenPermission {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Ventari Media";
    alert.informativeText = message ?: @"Recording failed.";
    alert.alertStyle = NSAlertStyleWarning;
    alert.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    if (needsScreenPermission) {
        [alert addButtonWithTitle:@"Open Settings"];
        [alert addButtonWithTitle:@"OK"];
        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [self.recorder openScreenRecordingSettings];
        }
    } else {
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

@end
