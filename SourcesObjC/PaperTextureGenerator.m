#import "PaperTextureGenerator.h"
#import <CoreGraphics/CoreGraphics.h>
#import <math.h>

#define TILE 512

// ── Noise math ────────────────────────────────────────────────────────────
static double _h(double x, double y, double s) {
    double n = sin(x*127.1 + y*311.7 + s*74.3) * 43758.5453;
    return n - floor(n);
}
static double _lp(double a, double b, double t) { return a + (b-a)*t; }
static double _sm(double t) { return t*t*(3-2*t); }
static double _n2(double x, double y, double s) {
    int ix=(int)floor(x), iy=(int)floor(y);
    double fx=_sm(x-ix), fy=_sm(y-iy);
    return _lp(_lp(_h(ix,iy,s),_h(ix+1,iy,s),fx),_lp(_h(ix,iy+1,s),_h(ix+1,iy+1,s),fx),fy);
}
static double _fbm(double x, double y, double s, int o) {
    double v=0,a=.5,f=1,t=0;
    for(int i=0;i<o;i++){v+=_n2(x*f,y*f,s+i*17)*a;t+=a;a*=.5;f*=2;}
    return v/t;
}

// BGRA layout on little-endian Mac: [i]=B [i+1]=G [i+2]=R [i+3]=A
static void _pxNoise(uint8_t *d, int w, int h, double amt, double sc, double seed,
                     double rB, double gB, double bB, int oct) {
    for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
        int i=(y*w+x)*4;
        double n=_fbm(x*sc,y*sc,seed,oct), delta=(n-.5)*2*amt*255;
        d[i+2]=(uint8_t)fmax(0,fmin(255,(double)d[i+2]+delta*rB));
        d[i+1]=(uint8_t)fmax(0,fmin(255,(double)d[i+1]+delta*gB));
        d[i]  =(uint8_t)fmax(0,fmin(255,(double)d[i]  +delta*bB));
    }
}

@implementation PaperTextureGenerator

+ (NSImage *)textureForType:(PMTextureType)type {
    PMColorRGB base = PMTextureBaseRGB(type);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, TILE, TILE, 8, 0, cs,
        kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cs);
    if (!ctx) return nil;

    CGContextSetRGBFillColor(ctx, base.r/255.0, base.g/255.0, base.b/255.0, 1.0);
    CGContextFillRect(ctx, CGRectMake(0,0,TILE,TILE));
    uint8_t *data = CGBitmapContextGetData(ctx);
    double seed = type * 100.0;

    // Channel weights per Vellum Design System: grain = (.95,.88,.70), amber = (1,.52,.08),
    // weave/fiber = (1,1,1); octaves: grain/amber 5, fiber 4, weave 3.
    switch (type) {
        case PMTextureWarmParchment:
            _pxNoise(data,TILE,TILE, 0.088, 0.022, seed, .95, .88, .70, 5);
            break;
        case PMTextureAgedLinen:
            _pxNoise(data,TILE,TILE, 0.04,  0.028, seed, 1.0, 1.0, 1.0, 3);
            [self drawWeave:ctx fr:165 fg:152 fb:135 seed:seed];
            break;
        case PMTextureIvoryScript:
            _pxNoise(data,TILE,TILE, 0.030, 0.042, seed, .95, .88, .70, 5);
            break;
        case PMTextureKraftPress:
            _pxNoise(data,TILE,TILE, 0.140, 0.018, seed, .95, .88, .70, 5);
            break;
        case PMTextureNewsprint:
            [self newsprint:data seed:seed];
            break;
        case PMTextureRicePaper:
            _pxNoise(data,TILE,TILE, 0.038, 0.026, seed, 1.0, 1.0, 1.0, 4);
            [self drawFibers:ctx seed:seed];
            break;
        case PMTextureBambooWeave:
            _pxNoise(data,TILE,TILE, 0.04,  0.028, seed, 1.0, 1.0, 1.0, 3);
            [self drawWeave:ctx fr:168 fg:178 fb:148 seed:seed];
            break;
        case PMTextureWatercolor:
            [self watercolor:data seed:seed];
            [self waterVignette:ctx];
            break;
        case PMTextureCreamVellum:
            _pxNoise(data,TILE,TILE, 0.022, 0.050, seed, .95, .88, .70, 5);
            break;
        case PMTextureDarkParchment:
            [self darkGrain:data seed:seed];
            break;
        case PMTextureAmberShield:
            _pxNoise(data,TILE,TILE, 0.070, 0.024, seed, 1.0, .52, .08, 5);
            break;
        case PMTextureNightGuard:
            _pxNoise(data,TILE,TILE, 0.055, 0.024, seed, 1.0, .52, .08, 5);
            break;
        default: break;
    }

    CGImageRef img = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    NSImage *result = [[NSImage alloc] initWithCGImage:img size:NSMakeSize(TILE,TILE)];
    CGImageRelease(img);
    return result;
}

+ (void)drawWeave:(CGContextRef)ctx fr:(int)fr fg:(int)fg fb:(int)fb seed:(double)seed {
    double r=fr/255.0, g=fg/255.0, b=fb/255.0;
    CGContextSaveGState(ctx);
    for(int y=2;y<TILE;y+=4) {
        CGContextSetRGBStrokeColor(ctx,r,g,b,0.25);
        CGContextSetLineWidth(ctx,0.75);
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx,0,y);
        for(int x=0;x<=TILE;x+=5) CGContextAddLineToPoint(ctx,x,y+(_h(x*.4,y*.4,seed)-.5)*1.6);
        CGContextStrokePath(ctx);
    }
    for(int x=2;x<TILE;x+=4) {
        CGContextSetRGBStrokeColor(ctx,r,g,b,0.18);
        CGContextSetLineWidth(ctx,0.75);
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx,x,0);
        for(int y=0;y<=TILE;y+=5) CGContextAddLineToPoint(ctx,x+(_h(x*.4,y*.4,seed+77)-.5)*1.6,y);
        CGContextStrokePath(ctx);
    }
    CGContextRestoreGState(ctx);
}

+ (void)drawFibers:(CGContextRef)ctx seed:(double)seed {
    CGContextSaveGState(ctx);
    for(int f=0;f<100;f++) {
        double r0=_h(f,0,seed),r1=_h(f,1,seed),r2=_h(f,2,seed);
        double r3=_h(f,3,seed),r4=_h(f,4,seed),r5=_h(f,5,seed);
        double x0=r0*TILE,y0=r1*TILE,len=50+r2*150;
        double ang=r3*M_PI*2,dx=cos(ang)*len,dy=sin(ang)*len;
        double cpx=x0+dx*.5+(r4-.5)*50, cpy=y0+dy*.5+(r5-.5)*50;
        CGContextSetRGBStrokeColor(ctx,138/255.0,118/255.0,88/255.0,.05+r2*.11);
        CGContextSetLineWidth(ctx,.35+r3*.85);
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx,x0,y0);
        CGContextAddQuadCurveToPoint(ctx,cpx,cpy,x0+dx,y0+dy);
        CGContextStrokePath(ctx);
    }
    CGContextRestoreGState(ctx);
}

+ (void)newsprint:(uint8_t *)d seed:(double)seed {
    for(int y=0;y<TILE;y++) {
        double band=(_n2(0,y*.04,seed)-.5)*12;
        for(int x=0;x<TILE;x++) {
            int i=(y*TILE+x)*4;
            double n=_fbm(x*.028,y*.028,seed+50,4), delta=(n-.5)*22+band;
            d[i+2]=(uint8_t)fmax(0,fmin(255,(double)d[i+2]+delta));
            d[i+1]=(uint8_t)fmax(0,fmin(255,(double)d[i+1]+delta));
            d[i]  =(uint8_t)fmax(0,fmin(255,(double)d[i]  +delta*.8));
        }
    }
}

+ (void)watercolor:(uint8_t *)d seed:(double)seed {
    for(int y=0;y<TILE;y++) for(int x=0;x<TILE;x++) {
        int i=(y*TILE+x)*4;
        double n=_fbm(x*.0055,y*.0055,seed,6)*.68+_fbm(x*.028,y*.028,seed+400,3)*.32;
        double delta=(n-.5)*38;
        d[i+2]=(uint8_t)fmax(0,fmin(255,(double)d[i+2]+delta*.82));
        d[i+1]=(uint8_t)fmax(0,fmin(255,(double)d[i+1]+delta*.70));
        d[i]  =(uint8_t)fmax(0,fmin(255,(double)d[i]  +delta*.52));
    }
}

+ (void)waterVignette:(CGContextRef)ctx {
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
    CGFloat c0[4]={0,0,0,0}, c1[4]={130/255.0,100/255.0,60/255.0,.16};
    CGFloat locs[2]={0,1};
    CGGradientRef g=CGGradientCreateWithColorComponents(cs,(CGFloat[]){
        c0[0],c0[1],c0[2],c0[3],c1[0],c1[1],c1[2],c1[3]},locs,2);
    CGContextDrawRadialGradient(ctx,g,
        CGPointMake(TILE/2.0,TILE/2.0),TILE*.25,
        CGPointMake(TILE/2.0,TILE/2.0),TILE*.78,
        kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

+ (void)darkGrain:(uint8_t *)d seed:(double)seed {
    for(int y=0;y<TILE;y++) for(int x=0;x<TILE;x++) {
        int i=(y*TILE+x)*4;
        double v=_fbm(x*.022,y*.022,seed,5)*62;
        d[i+2]=(uint8_t)fmax(0,fmin(255,(double)d[i+2]+v));
        d[i+1]=(uint8_t)fmax(0,fmin(255,(double)d[i+1]+v*.55));
        d[i]  =(uint8_t)fmax(0,fmin(255,(double)d[i]  +v*.18));
    }
}

@end
