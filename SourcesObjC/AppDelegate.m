#import "AppDelegate.h"
#import "SettingsStore.h"
#import "OverlayManager.h"
#import "MenuBarViewController.h"
#import "MenuBarPopover.h"
#import "AppManager.h"
#import "VellumIcon.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

@implementation AppDelegate {
    NSStatusItem           *_statusItem;
    NSWindow               *_controlsWindow;
    MenuBarViewController  *_menuVC;
    NSPanel                *_popoverPanel;
    MenuBarPopover         *_popover;
    id                      _popoverGlobalMon;
    id                      _popoverLocalMon;
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
    // Accessory (menu-bar) app: no Dock icon, and — crucially — its CanJoinAllSpaces
    // overlay window DOES float over OTHER apps' native-fullscreen Spaces. A Regular
    // app's non-active windows stay hidden behind the fullscreen app, which is why the
    // texture vanished in fullscreen. The controls window still shows normally.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    [self registerBundledFonts];
    // Vellum app icon (Finder, app switcher, and Dock if ever shown).
    NSApp.applicationIconImage = [VellumIcon iconWithSize:512];

    [self buildMainMenu];
    [self buildStatusItem];
    [self buildControlsWindow];

    // Restore saved overlay state
    if (SettingsStore.shared.isEnabled) {
        [OverlayManager.shared enable];
    }

    // Show the controls window on launch
    [self showControls];
}

// MARK: – Main menu (Cmd-Q etc.)

- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Hide Vellum"
                       action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Vellum"
                       action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSApp.mainMenu = mainMenu;
}

// MARK: – Status bar item (PM icon)

- (void)registerBundledFonts {
    NSArray *urls = [NSBundle.mainBundle URLsForResourcesWithExtension:@"ttf" subdirectory:@"fonts"];
    for (NSURL *u in urls) {
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)u, kCTFontManagerScopeProcess, NULL);
    }
}

- (void)buildStatusItem {
    _statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *btn = _statusItem.button;

    btn.target = self;
    btn.action = @selector(toggleControls:);
    // Accessory app has no Dock icon — left-click toggles controls, right-click quits.
    [btn sendActionOn:(NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp)];
    btn.toolTip = @"Vellum — click to open, right-click to quit";

    // The menu-bar "V" mark (Vellum Design System §01): gold pill when protection is
    // live, bare 82%-white V when off. Re-rendered on every state change below.
    [self refreshStatusMark];
    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(refreshStatusMark)
        name:VellumOverlayStateDidChange object:nil];
}

- (void)refreshStatusMark {
    SettingsStore *st = SettingsStore.shared;
    BOOL live = st.isEnabled && !st.isSnoozed;
    _statusItem.button.image = [VellumIcon menuBarMarkActive:live size:18];
}

// MARK: – Controls window (real window, above the overlay)

- (void)buildControlsWindow {
    _menuVC = [[MenuBarViewController alloc] init];
    NSView *vcView = _menuVC.view;           // triggers loadView
    NSSize size = vcView.frame.size;
    if (size.width == 0 || size.height == 0) size = NSMakeSize(610, 475);

    _controlsWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, size.width, size.height)
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    _controlsWindow.title = @"Vellum";
    _controlsWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    _controlsWindow.opaque = YES;
    _controlsWindow.backgroundColor = [NSColor colorWithSRGBRed:26/255.0 green:24/255.0 blue:22/255.0 alpha:1.0];

    // Host via a plain springs-and-struts container — no constraint engine,
    // so the manual-frame view tree can't throw an Auto Layout exception.
    NSView *host = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    host.wantsLayer = YES;
    host.layer.backgroundColor = [NSColor colorWithSRGBRed:26/255.0 green:24/255.0 blue:22/255.0 alpha:1.0].CGColor;
    host.translatesAutoresizingMaskIntoConstraints = YES;
    vcView.translatesAutoresizingMaskIntoConstraints = YES;
    vcView.frame = host.bounds;
    vcView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [host addSubview:vcView];
    _controlsWindow.contentView = host;

    _controlsWindow.releasedWhenClosed = NO;
    _controlsWindow.hidesOnDeactivate  = NO;

    // Sit above the paper overlay (now at NSScreenSaverWindowLevel) so the controls
    // are always visible and clickable, even while the overlay covers fullscreen apps.
    _controlsWindow.level = NSScreenSaverWindowLevel + 1;
    _controlsWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;

    [_controlsWindow center];
}

// MARK: – Show / hide

- (void)showControls {
    [_controlsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)toggleControls:(id)sender {
    NSEvent *e = NSApp.currentEvent;
    if (e.type == NSEventTypeRightMouseUp ||
        (e.modifierFlags & NSEventModifierFlagControl)) {
        NSMenu *m = [[NSMenu alloc] init];
        [m addItemWithTitle:@"Open Settings" action:@selector(showControls) keyEquivalent:@""].target = self;
        [m addItem:[NSMenuItem separatorItem]];
        [m addItemWithTitle:@"Quit Vellum" action:@selector(terminate:) keyEquivalent:@"q"];
        [NSMenu popUpContextMenu:m withEvent:e forView:_statusItem.button];
        return;
    }
    [self togglePopover];
}

// MARK: – Menu-bar popover (Vellum Menu Bar.dc.html)

- (void)togglePopover {
    if (_popoverPanel.isVisible) { [self closePopover]; return; }
    [self showPopover];
}

- (void)showPopover {
    if (!_popover) [self buildPopover];

    // Capture the app that was frontmost *before* we opened, for "Disable for X".
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (front && ![front.bundleIdentifier isEqualToString:@"com.papereye.local"]) {
        _popover.targetAppName  = front.localizedName;
        _popover.targetBundleId = front.bundleIdentifier;
    }
    [_popover refresh];

    // Anchor the panel just below the status-bar button, right-aligned to it.
    NSStatusBarButton *btn = _statusItem.button;
    NSRect br = [btn.window convertRectToScreen:btn.bounds];
    NSSize sz = _popoverPanel.frame.size;
    CGFloat x = NSMaxX(br) - sz.width + 6;
    CGFloat y = NSMinY(br) - 6 - sz.height;
    NSScreen *scr = btn.window.screen ?: NSScreen.mainScreen;
    CGFloat minX = NSMinX(scr.visibleFrame) + 6;
    CGFloat maxX = NSMaxX(scr.visibleFrame) - sz.width - 6;
    x = MAX(minX, MIN(x, maxX));
    [_popoverPanel setFrameOrigin:NSMakePoint(x, y)];
    [_popoverPanel makeKeyAndOrderFront:nil];

    // vmPop entrance: fade + drop 8px + scale .97 → 1 over .28s (Brief §8).
    CALayer *L = _popoverPanel.contentView.layer;
    CATransform3D from = CATransform3DTranslate(CATransform3DMakeScale(0.97,0.97,1), 0, 8, 0);
    CABasicAnimation *t = [CABasicAnimation animationWithKeyPath:@"transform"];
    t.fromValue = [NSValue valueWithCATransform3D:from];
    t.toValue   = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    CABasicAnimation *o = [CABasicAnimation animationWithKeyPath:@"opacity"];
    o.fromValue = @0; o.toValue = @1;
    CAAnimationGroup *g = [CAAnimationGroup animation];
    g.animations = @[t,o]; g.duration = 0.28;
    g.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.2:0.9:0.3:1.0];
    [L addAnimation:g forKey:@"vmPop"];

    __weak AppDelegate *ws = self;
    _popoverGlobalMon = [NSEvent addGlobalMonitorForEventsMatchingMask:
        (NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown)
        handler:^(NSEvent *ev){ [ws closePopover]; }];
    _popoverLocalMon = [NSEvent addLocalMonitorForEventsMatchingMask:
        (NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown)
        handler:^NSEvent *(NSEvent *ev){
            AppDelegate *s = ws; if (!s) return ev;
            // Skip clicks on the status-item button: its own action toggles the
            // popover. Without this guard the monitor closes first, then the
            // button action sees it hidden and re-opens it (close-then-reopen).
            if (ev.window != s->_popoverPanel &&
                ev.window != s->_statusItem.button.window) [s closePopover];
            return ev;
        }];
}

- (void)closePopover {
    if (_popoverGlobalMon) { [NSEvent removeMonitor:_popoverGlobalMon]; _popoverGlobalMon=nil; }
    if (_popoverLocalMon)  { [NSEvent removeMonitor:_popoverLocalMon];  _popoverLocalMon=nil;  }
    [_popoverPanel orderOut:nil];
}

- (void)buildPopover {
    _popover = [[MenuBarPopover alloc] init];
    NSView *content = _popover.view;             // triggers loadView (size CW×CH)
    NSSize sz = content.frame.size;

    __weak AppDelegate *ws = self;
    _popover.onOpenSettings = ^{ [ws closePopover]; [ws showControls]; };
    _popover.onQuit         = ^{ [NSApp terminate:nil]; };

    _popoverPanel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0,0,sz.width,sz.height)
                  styleMask:(NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel)
                    backing:NSBackingStoreBuffered defer:NO];
    _popoverPanel.opaque = NO;
    _popoverPanel.backgroundColor = NSColor.clearColor;
    _popoverPanel.hasShadow = YES;
    _popoverPanel.level = NSScreenSaverWindowLevel + 2;   // above overlay & controls
    _popoverPanel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    _popoverPanel.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                        NSWindowCollectionBehaviorFullScreenAuxiliary);

    // Rounded container: blurred backdrop + dark gradient tint + content.
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0,0,sz.width,sz.height)];
    container.wantsLayer = YES;
    container.layer.cornerRadius = 17;
    container.layer.masksToBounds = YES;
    container.layer.borderWidth = 1;
    container.layer.borderColor = [NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:0.07].CGColor;

    NSVisualEffectView *fx = [[NSVisualEffectView alloc] initWithFrame:container.bounds];
    fx.material = NSVisualEffectMaterialPopover;
    fx.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    fx.state = NSVisualEffectStateActive;
    fx.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    [container addSubview:fx];

    NSView *tint = [[NSView alloc] initWithFrame:container.bounds];
    tint.wantsLayer = YES; tint.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    CAGradientLayer *gl = [CAGradientLayer layer];
    gl.frame = container.bounds;
    gl.colors = @[(id)[NSColor colorWithSRGBRed:30/255.0 green:27/255.0 blue:24/255.0 alpha:0.90].CGColor,
                  (id)[NSColor colorWithSRGBRed:22/255.0 green:20/255.0 blue:18/255.0 alpha:0.92].CGColor];
    gl.startPoint = CGPointMake(0.5,0); gl.endPoint = CGPointMake(0.5,1);
    tint.layer = gl; tint.wantsLayer = YES;
    [container addSubview:tint];

    content.frame = container.bounds;
    content.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    [container addSubview:content];

    _popoverPanel.contentView = container;
}

// Re-open window when app icon is clicked in the dock / app relaunched
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app
                    hasVisibleWindows:(BOOL)flag {
    [self showControls];
    return YES;
}

// Closing the window must NOT quit — overlay keeps running in the background.
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return NO;
}

@end
