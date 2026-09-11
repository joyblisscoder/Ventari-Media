#import "SaveSheet.h"
#import "Brand.h"

@interface SaveSheet ()
@property (nonatomic, strong) NSWindow *sheet;
@property (nonatomic, strong) NSTextField *field;
@property (nonatomic, copy) void (^completion)(NSString *chosenName);
@end

@implementation SaveSheet

- (void)beginOnWindow:(NSWindow *)parent
        suggestedName:(NSString *)name
           completion:(void (^)(NSString *))completion {
    self.completion = completion;

    NSRect frame = NSMakeRect(0, 0, 380, 214);
    self.sheet = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:NSWindowStyleMaskTitled
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    self.sheet.title = @"Save recording";
    VRStyleWindow(self.sheet);
    self.sheet.releasedWhenClosed = NO;

    NSView *content = self.sheet.contentView;
    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.edgeInsets = NSEdgeInsetsMake(18, 20, 18, 20);
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]
    ]];

    [stack addArrangedSubview:VRLabel(@"Name this recording", VRHeadingFont(15), VRZincColor())];
    [stack addArrangedSubview:VRLabel(@"Saved to Desktop as an MP4.", VRBodyFont(12), VRMutedColor())];

    self.field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 340, 28)];
    self.field.stringValue = name ?: @"";
    self.field.font = VRBodyFont(13);
    self.field.bezelStyle = NSTextFieldRoundedBezel;
    self.field.focusRingType = NSFocusRingTypeNone;
    [self.field.widthAnchor constraintEqualToConstant:340].active = YES;
    [stack addArrangedSubview:self.field];

    NSStackView *actions = [NSStackView new];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.spacing = 10;
    actions.alignment = NSLayoutAttributeCenterY;

    NSButton *discard = [NSButton buttonWithTitle:@"Don't Save" target:self action:@selector(discard:)];
    discard.bezelStyle = NSBezelStyleRounded;
    discard.keyEquivalent = @"\033";

    NSButton *save = [NSButton buttonWithTitle:@"Save" target:self action:@selector(save:)];
    save.bezelStyle = NSBezelStyleRounded;
    save.keyEquivalent = @"\r";
    save.contentTintColor = VRGoldColor();

    [actions addArrangedSubview:discard];
    [actions addArrangedSubview:save];
    [stack addArrangedSubview:actions];

    [self.sheet makeFirstResponder:self.field];
    [parent beginSheet:self.sheet completionHandler:nil];
}

- (void)save:(id)sender {
    NSString *name = [self.field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self finishWithName:name.length ? name : self.field.stringValue];
}

- (void)discard:(id)sender {
    [self finishWithName:nil];
}

- (void)finishWithName:(NSString *)name {
    NSWindow *sheet = self.sheet;
    void (^done)(NSString *) = self.completion;
    self.completion = nil;
    self.sheet = nil;
    [NSApp endSheet:sheet];
    [sheet orderOut:nil];
    if (done) done(name);
}

@end
