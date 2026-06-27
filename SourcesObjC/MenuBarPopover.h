#import <AppKit/AppKit.h>

// The compact menu-bar quick-access panel (Vellum Menu Bar.dc.html).
// Hosted in a borderless panel anchored under the status-bar icon.
@interface MenuBarPopover : NSViewController
@property (nonatomic, copy) NSString *targetAppName;   // frontmost app when opened ("Figma")
@property (nonatomic, copy) NSString *targetBundleId;  // …its bundle id (for "Disable for")
@property (nonatomic, copy) void (^onOpenSettings)(void);
@property (nonatomic, copy) void (^onQuit)(void);
- (void)refresh;   // re-read SettingsStore/OverlayManager and update controls
@end
