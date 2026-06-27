#import "VellumIcon.h"

// Design space is 400×400 (from VellumIcon.dc.html). We draw in a flipped CG
// context so SVG (y-down) coordinates map 1:1, then scale to the requested px.

static CGGradientRef MakeGradient(CGFloat comps[], CGFloat locs[], size_t n) {
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, n);
    CGColorSpaceRelease(cs);
    return g;
}

@implementation VellumIcon

+ (void)drawArtInContext:(CGContextRef)ctx rounded:(BOOL)rounded {
    // ── Background ────────────────────────────────────────────────────────
    // radial vi-bg: cx158 cy120 r330  #2E2316 → (55%) #0C0804 → #050302
    {
        CGFloat comps[] = {
            0x2E/255.0,0x23/255.0,0x16/255.0,1,
            0x0C/255.0,0x08/255.0,0x04/255.0,1,
            0x05/255.0,0x03/255.0,0x02/255.0,1,
        };
        CGFloat locs[] = {0.0, 0.55, 1.0};
        CGGradientRef g = MakeGradient(comps, locs, 3);
        CGContextSaveGState(ctx);
        CGContextAddRect(ctx, CGRectMake(0,0,400,400));
        CGContextClip(ctx);
        CGContextDrawRadialGradient(ctx, g, CGPointMake(158,120), 0, CGPointMake(158,120), 330, kCGGradientDrawsAfterEndLocation);
        CGContextRestoreGState(ctx);
        CGGradientRelease(g);
    }

    // ── Halo glow ─────────────────────────────────────────────────────────
    // radial vi-halo: cx200 cy188 r156  rgba(228,170,46,.5) → (46%) rgba(198,140,40,.12) → 0
    {
        CGFloat comps[] = {
            228/255.0,170/255.0,46/255.0,0.50,
            198/255.0,140/255.0,40/255.0,0.12,
            198/255.0,140/255.0,40/255.0,0.00,
        };
        CGFloat locs[] = {0.0, 0.46, 1.0};
        CGGradientRef g = MakeGradient(comps, locs, 3);
        CGContextDrawRadialGradient(ctx, g, CGPointMake(200,188), 0, CGPointMake(200,188), 156, 0);
        CGGradientRelease(g);
    }

    // ── Orb body ──────────────────────────────────────────────────────────
    // circle (200,190) r98 filled with radial vi-orb (cx166 cy148 r158)
    {
        CGFloat comps[] = {
            0xFC/255.0,0xE7/255.0,0xAB/255.0,1, // 0%
            0xED/255.0,0xC3/255.0,0x5C/255.0,1, // 28%
            0xD0/255.0,0x8A/255.0,0x26/255.0,1, // 56%
            0x8E/255.0,0x54/255.0,0x17/255.0,1, // 82%
            0x4A/255.0,0x2B/255.0,0x0C/255.0,1, // 100%
        };
        CGFloat locs[] = {0.0, 0.28, 0.56, 0.82, 1.0};
        CGGradientRef g = MakeGradient(comps, locs, 5);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, CGRectMake(200-98,190-98,196,196));
        CGContextClip(ctx);
        CGContextDrawRadialGradient(ctx, g, CGPointMake(166,148), 0, CGPointMake(166,148), 158, kCGGradientDrawsAfterEndLocation);

        // ── Shade overlay (bottom-right) ──────────────────────────────────
        // radial vi-shade cx252 cy252 r150  rgba(18,7,0,.55) → (62%) 0
        CGFloat scomps[] = {
            18/255.0,7/255.0,0/255.0,0.55,
            18/255.0,7/255.0,0/255.0,0.00,
        };
        CGFloat slocs[] = {0.0, 0.62};
        CGGradientRef sg = MakeGradient(scomps, slocs, 2);
        CGContextDrawRadialGradient(ctx, sg, CGPointMake(252,252), 0, CGPointMake(252,252), 150, 0);
        CGGradientRelease(sg);
        CGContextRestoreGState(ctx);
        CGGradientRelease(g);
    }

    // ── Specular highlight arc ────────────────────────────────────────────
    // path M 132,150 A 98 98 0 0 1 250,108  → circular arc, center (165.7,58) r98
    {
        CGPoint p1 = CGPointMake(132,150), p2 = CGPointMake(250,108);
        CGPoint c  = CGPointMake(165.73, 58.0); CGFloat r = 98.0;
        CGFloat a1 = atan2(p1.y-c.y, p1.x-c.x);   // ~110°
        CGFloat a2 = atan2(p2.y-c.y, p2.x-c.x);   // ~31°
        CGMutablePathRef path = CGPathCreateMutable();
        // minor arc (large-arc=0): sweep from a2 up to a1, clockwise=NO in this y-down space
        CGPathAddArc(path, NULL, c.x, c.y, r, a2, a1, NO);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineWidth(ctx, 2.5);
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithSRGBRed:255/255.0 green:243/255.0 blue:210/255.0 alpha:0.55].CGColor);
        CGContextAddPath(ctx, path);
        CGContextStrokePath(ctx);
        CGPathRelease(path);
    }

    // ── Film grain ────────────────────────────────────────────────────────
    // feTurbulence fractalNoise, saturate 0, soft-light, ~0.34 alpha.
    // Approximated with deterministic per-cell grayscale noise.
    {
        CGContextSaveGState(ctx);
        CGContextSetBlendMode(ctx, kCGBlendModeSoftLight);
        CGContextSetAlpha(ctx, 0.85);
        unsigned int seed = 0x5EED1234;
        const CGFloat cell = 1.6; // grain cell size in design units
        for (CGFloat y=0; y<400; y+=cell) {
            for (CGFloat x=0; x<400; x+=cell) {
                seed = seed*1664525u + 1013904223u;
                CGFloat v = ((seed>>16)&0xFF)/255.0;     // 0..1 gray
                CGFloat a = 0.40 * (((seed>>8)&0xFF)/255.0); // alpha jitter
                CGContextSetRGBFillColor(ctx, v, v, v, a);
                CGContextFillRect(ctx, CGRectMake(x,y,cell,cell));
            }
        }
        CGContextRestoreGState(ctx);
    }

    // ── Inner hairline border ─────────────────────────────────────────────
    if (rounded) {
        CGPathRef bp = CGPathCreateWithRoundedRect(CGRectMake(1,1,398,398), 89, 89, NULL);
        CGContextAddPath(ctx, bp);
        CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:0.07].CGColor);
        CGContextSetLineWidth(ctx, 2);
        CGContextStrokePath(ctx);
        CGPathRelease(bp);
    }
}

+ (NSImage *)renderSize:(CGFloat)px rounded:(BOOL)rounded {
    if (px < 1) px = 1;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)px pixelsHigh:(NSInteger)px
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    rep.size = NSMakeSize(px, px);

    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = gc;
    CGContextRef ctx = gc.CGContext;

    // Map design (400, y-down) → bitmap (px, y-up)
    CGContextScaleCTM(ctx, px/400.0, px/400.0);
    CGContextTranslateCTM(ctx, 0, 400);
    CGContextScaleCTM(ctx, 1, -1);

    if (rounded) {
        CGPathRef clip = CGPathCreateWithRoundedRect(CGRectMake(0,0,400,400), 90, 90, NULL);
        CGContextAddPath(ctx, clip);
        CGContextClip(ctx);
        CGPathRelease(clip);
    } else {
        CGContextAddEllipseInRect(ctx, CGRectMake(200-98,190-98,196,196));
        CGContextClip(ctx);
    }
    [self drawArtInContext:ctx rounded:rounded];

    [NSGraphicsContext restoreGraphicsState];

    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(px, px)];
    [img addRepresentation:rep];
    return img;
}

+ (NSImage *)iconWithSize:(CGFloat)px    { return [self renderSize:px rounded:YES]; }
+ (NSImage *)flatOrbWithSize:(CGFloat)px { return [self renderSize:px rounded:NO]; }

// ── Sidebar section icons (§04 of the Vellum Design System) ─────────────
// Line icons drawn on a 12×12 viewBox, 1.3pt stroke, currentColor.
// In AppKit y-up we flip: y_appkit = (12 - y_svg) * scale.
+ (NSImage *)sidebarIconAtIndex:(NSInteger)idx size:(CGFloat)pt {
    NSImage *img = [NSImage imageWithSize:NSMakeSize(pt, pt) flipped:NO drawingHandler:^BOOL(NSRect __unused r) {
        CGFloat s = pt / 12.0;
#define SX(x)    ((x)*s)
#define SY(y)    ((12-(y))*s)
#define SP(x,y)  NSMakePoint(SX(x), SY(y))
        NSBezierPath *bp = [NSBezierPath bezierPath];
        bp.lineWidth = 1.3 * s;
        bp.lineCapStyle  = NSLineCapStyleRound;
        bp.lineJoinStyle = NSLineJoinStyleRound;
        [NSColor.blackColor set];

        switch (idx) {
            case 0: { // Protection – shield
                // M6,.5 L.5,3 V6 c0,3.2 2.5,5.3 5.5,5.7 C9,10.3 11.5,8.2 11.5,6 V3 L6,.5 z
                [bp moveToPoint:SP(6,.5)];
                [bp lineToPoint:SP(.5,3)];
                [bp lineToPoint:SP(.5,6)];
                [bp curveToPoint:SP(6,11.7) controlPoint1:SP(.5,9.2) controlPoint2:SP(3,11.3)];
                [bp curveToPoint:SP(11.5,6) controlPoint1:SP(9,10.3) controlPoint2:SP(11.5,8.2)];
                [bp lineToPoint:SP(11.5,3)];
                [bp lineToPoint:SP(6,.5)];
                [bp closePath];
                break;
            }
            case 1: { // Textures – three wavy lines
                [bp moveToPoint:SP(.5,3.5)];
                [bp curveToPoint:SP(11.5,3.5) controlPoint1:SP(3.5,2)  controlPoint2:SP(8.5,5)];
                [bp moveToPoint:SP(.5,6.5)];
                [bp curveToPoint:SP(11.5,6.5) controlPoint1:SP(3.5,5)  controlPoint2:SP(8.5,8)];
                [bp moveToPoint:SP(.5,9.5)];
                [bp curveToPoint:SP(11.5,9.5) controlPoint1:SP(3.5,8)  controlPoint2:SP(8.5,11)];
                break;
            }
            case 2: { // Circadian – crescent moon
                // SVG: M8.5,2 A4.5,4.5 0,0,1 8.5,10  A5,5 0,1,0 8.5,2 z
                // Arc1: center (6.438,6), r=4.5, minor, CW → AppKit CW start=62.76° end=-62.76°
                // Arc2: center (11.5,6),  r=5.0, major, CCW → AppKit CCW start=-126.87° end=126.87°
                [bp moveToPoint:NSMakePoint(SX(8.5), SY(2))];  // AppKit: (8.5s, 10s)
                [bp appendBezierPathWithArcWithCenter:NSMakePoint(SX(6.438), SY(6))
                                              radius:4.5*s startAngle:62.76 endAngle:-62.76 clockwise:YES];
                [bp appendBezierPathWithArcWithCenter:NSMakePoint(SX(11.5), SY(6))
                                              radius:5.0*s startAngle:-126.87 endAngle:126.87 clockwise:NO];
                [bp closePath];
                break;
            }
            case 3: { // Display – monitor + stand + base
                // M.5,1.5 h11 v7.5 H.5 z
                [bp moveToPoint:SP(.5,1.5)];
                [bp lineToPoint:SP(11.5,1.5)];
                [bp lineToPoint:SP(11.5,9)];   // 1.5+7.5
                [bp lineToPoint:SP(.5,9)];
                [bp closePath];
                // M4,9 l-.5,2.5 h5 L8,9
                [bp moveToPoint:SP(4,9)];
                [bp lineToPoint:SP(3.5,11.5)];
                [bp lineToPoint:SP(8.5,11.5)];
                [bp lineToPoint:SP(8,9)];
                // M3,11.5 h6
                [bp moveToPoint:SP(3,11.5)];
                [bp lineToPoint:SP(9,11.5)];
                break;
            }
            case 4: { // Exceptions – circle with X
                [bp appendBezierPathWithOvalInRect:NSMakeRect(.5*s,.5*s,11*s,11*s)];
                [bp moveToPoint:SP(3.5,3.5)]; [bp lineToPoint:SP(8.5,8.5)];
                [bp moveToPoint:SP(8.5,3.5)]; [bp lineToPoint:SP(3.5,8.5)];
                break;
            }
            case 5: { // License – circle with checkmark
                [bp appendBezierPathWithOvalInRect:NSMakeRect(.5*s,.5*s,11*s,11*s)];
                [bp moveToPoint:SP(3.5,6)];
                [bp lineToPoint:SP(5.5,8)];
                [bp lineToPoint:SP(9,3.5)];
                break;
            }
        }
        [bp stroke];
#undef SX
#undef SY
#undef SP
        return YES;
    }];
    img.template = YES;
    return img;
}

+ (NSImage *)menuBarMarkActive:(BOOL)active size:(CGFloat)pt {
    if (pt < 1) pt = 1;
    CGFloat h = pt, w = ceil(pt * 1.18);   // pill a touch wider than tall (design 38:31)
    // Cormorant Garamond is registered at launch; fall back to other serifs gracefully.
    NSFont *vf = [NSFont fontWithName:@"CormorantGaramond-SemiBold" size:h * 0.86]
                 ?: [NSFont fontWithName:@"Hoefler Text" size:h * 0.80]
                 ?: [NSFont fontWithName:@"Georgia-Bold" size:h * 0.78]
                 ?: [NSFont systemFontOfSize:h * 0.74 weight:NSFontWeightSemibold];

    return [NSImage imageWithSize:NSMakeSize(w, h) flipped:NO drawingHandler:^BOOL(NSRect r) {
        if (active) {
            NSRect pill = NSInsetRect(r, 0.5, 1.0);
            CGFloat rad = pill.size.height * 0.32;
            NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:pill xRadius:rad yRadius:rad];
            [[NSColor colorWithSRGBRed:212/255.0 green:188/255.0 blue:96/255.0 alpha:0.26] setFill];
            [bp fill];
            bp.lineWidth = 1.0;
            [[NSColor colorWithSRGBRed:212/255.0 green:188/255.0 blue:96/255.0 alpha:0.30] setStroke];
            [bp stroke];
        }
        NSColor *glyph = active
            ? [NSColor colorWithSRGBRed:242/255.0 green:223/255.0 blue:160/255.0 alpha:1.0] // #F2DFA0
            : [NSColor colorWithWhite:1.0 alpha:0.82];                                       // idle
        NSAttributedString *v = [[NSAttributedString alloc] initWithString:@"V"
            attributes:@{NSFontAttributeName:vf, NSForegroundColorAttributeName:glyph}];
        NSSize ts = v.size;
        [v drawAtPoint:NSMakePoint(r.origin.x + (w - ts.width) / 2.0,
                                   r.origin.y + (h - ts.height) / 2.0)];
        return YES;
    }];
}

@end
