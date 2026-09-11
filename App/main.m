#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;

        NSMenu *menubar = [NSMenu new];
        NSMenuItem *appItem = [NSMenuItem new];
        [menubar addItem:appItem];
        NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Ventari Media"];
        NSMenuItem *siteItem = [[NSMenuItem alloc] initWithTitle:@"ventari.media" action:@selector(openSite:) keyEquivalent:@""];
        siteItem.target = delegate;
        [appMenu addItem:siteItem];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Quit Ventari Media" action:@selector(terminate:) keyEquivalent:@"q"];
        appItem.submenu = appMenu;
        app.mainMenu = menubar;

        [app run];
    }
    return 0;
}
