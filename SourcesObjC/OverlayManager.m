#import "OverlayManager.h"
#import "SettingsStore.h"
#import "TextureOverlayView.h"

NSNotificationName const VellumOverlayStateDidChange = @"VellumOverlayStateDidChange";

@interface PMOverlayWindow : NSWindow
@end
@implementation PMOverlayWindow
- (BOOL)canBecomeKeyWindow  { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@implementation OverlayManager {
    NSMutableArray<PMOverlayWindow *> *_windows;
    BOOL _overlayVisible;
    BOOL _snoozed;
}

+ (instancetype)shared {
    static OverlayManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    _windows = [NSMutableArray array];
    return self;
}

- (void)enable {
    [self teardown];
    _isActive = YES;
    _overlayVisible = YES;
    _snoozed = SettingsStore.shared.isSnoozed;
    SettingsStore *st = SettingsStore.shared;
    for (NSScreen *screen in NSScreen.screens) {
        PMOverlayWindow *w = [self makeWindowForScreen:screen
                                             intensity:st.intensity
                                               texture:st.selectedTexture];
        [_windows addObject:w];
        if (!_snoozed) [w orderFront:nil];
    }
    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(screensChanged)
        name:NSApplicationDidChangeScreenParametersNotification object:nil];
    // Workspace notifications post ONLY to the workspace notification centre, not the
    // default centre — observing them on the default centre means they never fire.
    NSNotificationCenter *wc = NSWorkspace.sharedWorkspace.notificationCenter;
    [wc addObserver:self selector:@selector(appFocusChanged)
               name:NSWorkspaceDidActivateApplicationNotification object:nil];
    // When another app enters/leaves native full-screen a new Space becomes active;
    // re-order the overlays so they follow into that Space and stay on top.
    [wc addObserver:self selector:@selector(spaceChanged)
               name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
    [self updateVisibilityForFocusedApp];
    [NSNotificationCenter.defaultCenter postNotificationName:VellumOverlayStateDidChange object:self];
}

- (void)spaceChanged {
    if (!_isActive || _snoozed || !_overlayVisible) return;
    // Space transitions are async; orderFront: during the animation is dropped.
    // 0.3 s covers the standard ~0.25 s fullscreen transition.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!self->_isActive || self->_snoozed || !self->_overlayVisible) return;
        for (PMOverlayWindow *w in self->_windows) [w orderFront:nil];
    });
}

- (void)disable {
    [self teardown];
    [NSNotificationCenter.defaultCenter postNotificationName:VellumOverlayStateDidChange object:self];
}

- (void)setSnooze:(BOOL)snooze {
    _snoozed = snooze;
    SettingsStore.shared.isSnoozed = snooze;
    [NSNotificationCenter.defaultCenter postNotificationName:VellumOverlayStateDidChange object:self];
    if (!_isActive) return;
    if (snooze) {
        for (PMOverlayWindow *w in _windows) [w orderOut:nil];
        _overlayVisible = NO;
    } else {
        [self updateVisibilityForFocusedApp];
    }
}

- (void)update {
    SettingsStore *st = SettingsStore.shared;
    for (PMOverlayWindow *w in _windows) {
        TextureOverlayView *v = (TextureOverlayView *)w.contentView;
        v.intensity   = st.intensity;
        v.textureType = st.selectedTexture;
    }
}

- (void)teardown {
    _isActive = NO;
    for (NSWindow *w in _windows) { [w orderOut:nil]; [w close]; }
    [_windows removeAllObjects];
    [NSNotificationCenter.defaultCenter removeObserver:self
        name:NSApplicationDidChangeScreenParametersNotification object:nil];
    NSNotificationCenter *wc = NSWorkspace.sharedWorkspace.notificationCenter;
    [wc removeObserver:self name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [wc removeObserver:self name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
}

- (PMOverlayWindow *)makeWindowForScreen:(NSScreen *)screen
                               intensity:(double)intensity
                                 texture:(PMTextureType)texture {
    PMOverlayWindow *win = [[PMOverlayWindow alloc]
        initWithContentRect:screen.frame
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.opaque             = NO;
    win.backgroundColor    = NSColor.clearColor;
    win.ignoresMouseEvents = YES;
    win.hasShadow          = NO;
    win.releasedWhenClosed = NO;
    // Screen-saver level sits above other apps' native-fullscreen content. As an
    // accessory app, a plain CanJoinAllSpaces window DOES render inside other apps'
    // fullscreen Spaces (verified with our controls window). FullScreenAuxiliary, by
    // contrast, ties the window to OUR own fullscreen window and suppresses it in other
    // apps' Spaces — so it must NOT be set here.
    win.level              = NSScreenSaverWindowLevel;
    win.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces |
                              NSWindowCollectionBehaviorStationary       |
                              NSWindowCollectionBehaviorIgnoresCycle);
    TextureOverlayView *view = [[TextureOverlayView alloc]
        initWithFrame:screen.frame intensity:intensity texture:texture];
    win.contentView = view;
    return win;
}

- (void)screensChanged {
    if (_isActive) [self enable];
}

- (void)appFocusChanged {
    [self updateVisibilityForFocusedApp];
}

- (void)updateVisibilityForFocusedApp {
    if (!_isActive || _snoozed) return;
    NSString *focusedBundle = NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier;
    if (!focusedBundle || [focusedBundle isEqualToString:@"com.papereye.local"]) return;
    BOOL shouldHide = focusedBundle && [SettingsStore.shared isAppExcluded:focusedBundle];
    BOOL shouldShow = !shouldHide;
    if (_overlayVisible == shouldShow) return;
    _overlayVisible = shouldShow;
    for (PMOverlayWindow *w in _windows) {
        if (shouldShow) [w orderFront:nil];
        else            [w orderOut:nil];
    }
}

@end
