#import "TextureOverlayView.h"
#import "PaperTextureGenerator.h"

@implementation TextureOverlayView {
    NSImage *_cachedTexture;
    PMTextureType _lastType;
}

- (instancetype)initWithFrame:(NSRect)frame
                    intensity:(double)intensity
                      texture:(PMTextureType)texture {
    self = [super initWithFrame:frame];
    _intensity   = intensity;
    _textureType = texture;
    _lastType    = -1;
    return self;
}

- (void)setIntensity:(double)v    { _intensity = v;   [self setNeedsDisplay:YES]; }
- (void)setTextureType:(PMTextureType)v {
    if (_textureType != v) { _cachedTexture = nil; }
    _textureType = v;
    [self setNeedsDisplay:YES];
}

- (NSImage *)texture {
    if (!_cachedTexture || _lastType != _textureType) {
        _cachedTexture = [PaperTextureGenerator textureForType:_textureType];
        _lastType = _textureType;
    }
    return _cachedTexture;
}

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    if (!ctx) return;

    CGFloat alpha = (CGFloat)_intensity;
    NSColor *base = PMTextureBaseColor(_textureType);
    CGFloat r, g, b, a;
    [base getRed:&r green:&g blue:&b alpha:&a];

    // Pass 1 – colour tint
    CGContextSetBlendMode(ctx, PMTextureIsDark(_textureType)
        ? kCGBlendModeMultiply : kCGBlendModeNormal);
    CGContextSetRGBFillColor(ctx, r, g, b,
        (PMTextureIsDark(_textureType) ? 0.80f : 0.48f) * alpha);
    CGContextFillRect(ctx, self.bounds);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);

    // Pass 2 – paper grain (soft-light, fraction carries the alpha)
    NSImage *tex = [self texture];
    CGFloat sz   = 512.0;
    int tilesX   = (int)ceil(NSWidth(self.bounds)  / sz) + 1;
    int tilesY   = (int)ceil(NSHeight(self.bounds) / sz) + 1;

    for (int tx = 0; tx < tilesX; tx++) {
        for (int ty = 0; ty < tilesY; ty++) {
            NSRect tile = NSMakeRect(tx * sz, ty * sz, sz, sz);
            [tex drawInRect:tile fromRect:NSZeroRect
                  operation:NSCompositingOperationSoftLight
                   fraction:0.45 * alpha
             respectFlipped:YES hints:nil];
        }
    }
}

@end
