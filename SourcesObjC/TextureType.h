#pragma once
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, PMTextureType) {
    // Daytime textures
    PMTextureWarmParchment = 0,
    PMTextureAgedLinen     = 1,
    PMTextureIvoryScript   = 2,
    PMTextureKraftPress    = 3,
    PMTextureNewsprint     = 4,
    PMTextureRicePaper     = 5,
    PMTextureBambooWeave   = 6,
    PMTextureWatercolor    = 7,
    PMTextureCreamVellum   = 8,
    // Nighttime textures
    PMTextureDarkParchment = 9,
    PMTextureAmberShield   = 10,
    PMTextureNightGuard    = 11,
    PMTextureCount         = 12
};

typedef struct { double r, g, b; } PMColorRGB;

static inline NSString *PMTextureName(PMTextureType t) {
    switch (t) {
        case PMTextureWarmParchment: return @"Warm Parchment";
        case PMTextureAgedLinen:     return @"Aged Linen";
        case PMTextureIvoryScript:   return @"Ivory Script";
        case PMTextureKraftPress:    return @"Kraft Press";
        case PMTextureNewsprint:     return @"Newsprint";
        case PMTextureRicePaper:     return @"Rice Paper";
        case PMTextureBambooWeave:   return @"Bamboo Weave";
        case PMTextureWatercolor:    return @"Watercolor";
        case PMTextureCreamVellum:   return @"Cream Vellum";
        case PMTextureDarkParchment: return @"Dark Parchment";
        case PMTextureAmberShield:   return @"Amber Shield";
        case PMTextureNightGuard:    return @"Night Guard";
        default:                     return @"Unknown";
    }
}

static inline PMColorRGB PMTextureBaseRGB(PMTextureType t) {
    PMColorRGB v[] = {
        {245,237,214},{237,232,222},{251,247,238},
        {196,165,118},{224,218,203},{248,244,237},
        {229,235,215},{241,235,224},{249,246,241},
        {28,20,14},{255,186,102},{255,122,55}
    };
    if (t >= 0 && t < PMTextureCount) return v[t];
    return (PMColorRGB){245,237,214};
}

static inline NSColor *PMTextureBaseColor(PMTextureType t) {
    PMColorRGB c = PMTextureBaseRGB(t);
    return [NSColor colorWithSRGBRed:c.r/255.0 green:c.g/255.0 blue:c.b/255.0 alpha:1.0];
}

static inline BOOL PMTextureIsBlueLight(PMTextureType t) {
    return t == PMTextureAmberShield || t == PMTextureNightGuard;
}

static inline BOOL PMTextureIsNighttime(PMTextureType t) {
    return t >= PMTextureDarkParchment;
}

static inline BOOL PMTextureIsDark(PMTextureType t) {
    return t == PMTextureDarkParchment;
}

static inline double PMTextureDefaultOpacity(PMTextureType t) {
    double d[] = {0.40,0.45,0.32,0.35,0.42,0.44,0.40,0.38,0.28,0.18,0.50,0.60};
    if (t >= 0 && t < PMTextureCount) return d[t];
    return 0.40;
}
