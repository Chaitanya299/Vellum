#import <AppKit/AppKit.h>

// Posted whenever protection live-ness changes (enable / disable / snooze) so the
// menu-bar "V" mark can re-render its active/idle state. live = isEnabled && !isSnoozed.
extern NSNotificationName const VellumOverlayStateDidChange;

@interface OverlayManager : NSObject
@property (readonly) BOOL isActive;
+ (instancetype)shared;
- (void)enable;
- (void)disable;
- (void)update;
- (void)setSnooze:(BOOL)snooze;
- (void)updateVisibilityForFocusedApp;
@end
