#import <AppKit/AppKit.h>

// Procedural renderer for the Vellum app icon (matches VellumIcon.dc.html):
// a warm glowing amber orb on a dark rounded-square, with halo glow, a specular
// highlight arc, fine film grain, and a hairline inner border.
@interface VellumIcon : NSObject
+ (NSImage *)iconWithSize:(CGFloat)px;        // square, rounded (macOS-style superellipse-ish)
+ (NSImage *)flatOrbWithSize:(CGFloat)px;     // orb only, transparent bg (for small inline marks)

// Six sidebar section icons (§04). idx 0–5: Protection, Textures, Circadian, Display,
// Exceptions, License. Line icons, 1.3pt stroke, template (tinted via contentTintColor).
+ (NSImage *)sidebarIconAtIndex:(NSInteger)idx size:(CGFloat)pt;

// Menu-bar mark (Vellum Design System §01): a Cormorant Garamond "V". Active sits in
// a gold pill (rgba(212,188,96,.26)) with a #F2DFA0 glyph; idle is a bare 82%-white V.
// `pt` is the image height in points (≈18 for the menu bar); width is auto.
+ (NSImage *)menuBarMarkActive:(BOOL)active size:(CGFloat)pt;
@end
