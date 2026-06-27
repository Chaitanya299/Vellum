#import "MenuBarPopover.h"
#import "SettingsStore.h"
#import "OverlayManager.h"
#import "AppManager.h"
#import "TextureType.h"
#import "PaperTextureGenerator.h"
#import "VellumIcon.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>

// ── Colors ────────────────────────────────────────────────────────────────
static NSColor *HEX(CGFloat r,CGFloat g,CGFloat b){ return [NSColor colorWithSRGBRed:r/255 green:g/255 blue:b/255 alpha:1]; }
static NSColor *HEXA(CGFloat r,CGFloat g,CGFloat b,CGFloat a){ return [NSColor colorWithSRGBRed:r/255 green:g/255 blue:b/255 alpha:a]; }

// ── Layout ────────────────────────────────────────────────────────────────
#define CW   316.0   // content width
#define CH   380.0   // content height
#define PAD   15.0
#define IW   (CW-2*PAD)   // 286 inner width
// design "top" → NSView y-from-bottom
#define TY(t,h) (CH-(t)-(h))

// Wordmark font with elegant fallbacks (Cormorant Garamond SemiBold is bundled).
static NSFont *Cormorant(CGFloat size){
    return [NSFont fontWithName:@"CormorantGaramond-SemiBold" size:size]
        ?: [NSFont fontWithName:@"Hoefler Text" size:size]
        ?: [NSFont systemFontOfSize:size weight:NSFontWeightSemibold];
}

// ── Generic clickable, layer-backed card ──────────────────────────────────
@interface VCard : NSView
@property (nonatomic, copy) void (^onTap)(void);
@end
@implementation VCard
- (instancetype)initWithFrame:(NSRect)f { self=[super initWithFrame:f]; if(self) self.wantsLayer=YES; return self; }
- (void)mouseUp:(NSEvent*)e {
    if (NSPointInRect([self convertPoint:e.locationInWindow fromView:nil],self.bounds)&&_onTap) _onTap();
}
- (BOOL)acceptsFirstMouse:(NSEvent*)e { return YES; }
@end

// ── Quick-texture model ───────────────────────────────────────────────────
typedef struct { PMTextureType type; double def; BOOL isNew; } QTex;
static QTex kQuick[4] = {
    { PMTextureWarmParchment, 0.40, NO },
    { PMTextureAgedLinen,     0.45, NO },
    { PMTextureRicePaper,     0.44, NO },
    { PMTextureCreamVellum,   0.28, YES },
};
static NSString *kShort[4] = { @"Parchment", @"Aged Linen", @"Rice Paper", @"Vellum" };

@implementation MenuBarPopover {
    VCard       *_toggleCard;
    NSView      *_orbWrap;
    NSImageView *_orb;
    NSTextField *_toggleStatus;
    NSTextField *_intPct;
    NSSlider    *_slider;
    VCard       *_snoozeCard; NSImageView *_snoozeIco; NSTextField *_snoozeLbl;
    VCard       *_disableCard; NSImageView *_disableIco; NSTextField *_disL1; NSTextField *_disL2;
    NSTextField *_disHint;
    VCard       *_texCards[4];
    NSImageView *_texThumb[4];
    NSView      *_texCheck[4];
    NSTextField *_texLabel[4];
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0,0,CW,CH)];
    root.wantsLayer = YES;
    self.view = root;
    [self buildHeader:root];
    [self buildControls:root];
    [self buildTextures:root];
    [self buildFooter:root];
    [self generateThumbs];
    [self refresh];
}

// ── Header ────────────────────────────────────────────────────────────────
- (void)buildHeader:(NSView*)root {
    NSImageView *icon=[NSImageView imageViewWithImage:[VellumIcon iconWithSize:60]];
    icon.frame=NSMakeRect(PAD, TY(15,30), 30, 30);
    icon.wantsLayer=YES; icon.layer.cornerRadius=8; icon.layer.masksToBounds=YES;
    [root addSubview:icon];

    NSTextField *mark=[NSTextField labelWithString:@"Vellum"];
    mark.font=Cormorant(20); mark.textColor=HEX(239,230,210);
    mark.frame=NSMakeRect(55, TY(13,22), 140, 22); [root addSubview:mark];

    NSDictionary *ta=@{NSFontAttributeName:[NSFont systemFontOfSize:8.5 weight:NSFontWeightMedium],
                       NSForegroundColorAttributeName:HEX(138,106,68),
                       NSKernAttributeName:@(1.5)};
    NSTextField *tag=[NSTextField labelWithAttributedString:
        [[NSAttributedString alloc] initWithString:@"EASE THE LIGHT" attributes:ta]];
    tag.frame=NSMakeRect(55, TY(37,10), 180, 10); [root addSubview:tag];
}

// ── Controls grid ─────────────────────────────────────────────────────────
- (void)buildControls:(NSView*)root {
    CGFloat gridTop=56, leftW=IW-90, rightX=PAD+leftW+8;

    // Toggle card
    _toggleCard=[[VCard alloc] initWithFrame:NSMakeRect(PAD, TY(gridTop,66), leftW, 66)];
    _toggleCard.layer.cornerRadius=12; _toggleCard.layer.borderWidth=1;
    __weak MenuBarPopover *ws=self; _toggleCard.onTap=^{ [ws tapToggle]; };
    // Orb in a non-clipping wrapper so the vmGlow shadow can spill outside it.
    _orbWrap=[[NSView alloc] initWithFrame:NSMakeRect(12,(66-34)/2,34,34)];
    _orbWrap.wantsLayer=YES; _orbWrap.layer.cornerRadius=9;
    _orbWrap.layer.shadowColor=HEX(200,168,64).CGColor;
    _orbWrap.layer.shadowOffset=CGSizeZero; _orbWrap.layer.shadowOpacity=0;
    _orb=[NSImageView imageViewWithImage:[VellumIcon iconWithSize:68]];
    _orb.frame=_orbWrap.bounds;
    _orb.wantsLayer=YES; _orb.layer.cornerRadius=9; _orb.layer.masksToBounds=YES;
    [_orbWrap addSubview:_orb];
    [_toggleCard addSubview:_orbWrap];
    NSTextField *tt=[NSTextField labelWithString:@"Vellum Effect"];
    tt.font=[NSFont systemFontOfSize:13.5 weight:NSFontWeightSemibold]; tt.textColor=HEX(234,226,208);
    tt.frame=NSMakeRect(56, 66-12-22, leftW-62, 18); [_toggleCard addSubview:tt];
    _toggleStatus=[NSTextField labelWithString:@""];
    _toggleStatus.font=[NSFont systemFontOfSize:10.5]; _toggleStatus.lineBreakMode=NSLineBreakByTruncatingTail;
    _toggleStatus.frame=NSMakeRect(56, 66-12-22-16, leftW-62, 14); [_toggleCard addSubview:_toggleStatus];
    [root addSubview:_toggleCard];

    // Intensity card
    VCard *icard=[[VCard alloc] initWithFrame:NSMakeRect(PAD, TY(gridTop+66+8,58), leftW, 58)];
    icard.layer.cornerRadius=12; icard.layer.borderWidth=1;
    icard.layer.backgroundColor=HEXA(0,0,0,.24).CGColor; icard.layer.borderColor=HEXA(255,255,255,.06).CGColor;
    NSTextField *il=[NSTextField labelWithString:@"Intensity"];
    il.font=[NSFont systemFontOfSize:11 weight:NSFontWeightMedium]; il.textColor=HEX(154,138,116);
    il.frame=NSMakeRect(12, 58-9-13, 80, 14); [icard addSubview:il];
    _intPct=[NSTextField labelWithString:@"40%"];
    _intPct.font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightSemibold];
    _intPct.textColor=HEX(212,188,96); _intPct.alignment=NSTextAlignmentRight;
    _intPct.frame=NSMakeRect(leftW-52, 58-9-13, 40, 14); [icard addSubview:_intPct];
    NSTextField *lo=[NSTextField labelWithString:@"○"];
    lo.font=[NSFont systemFontOfSize:10]; lo.textColor=HEX(96,80,64);
    lo.frame=NSMakeRect(12, 10, 12, 14); [icard addSubview:lo];
    NSTextField *hi=[NSTextField labelWithString:@"◉"];
    hi.font=[NSFont systemFontOfSize:12]; hi.textColor=HEX(122,106,80);
    hi.frame=NSMakeRect(leftW-24, 9, 14, 16); [icard addSubview:hi];
    _slider=[[NSSlider alloc] initWithFrame:NSMakeRect(28, 9, leftW-58, 16)];
    _slider.minValue=0.05; _slider.maxValue=1.0; _slider.continuous=YES;
    _slider.target=self; _slider.action=@selector(sliderChanged:);
    [icard addSubview:_slider];
    [root addSubview:icard];

    // Snooze card
    _snoozeCard=[[VCard alloc] initWithFrame:NSMakeRect(rightX, TY(gridTop,62), 82, 62)];
    _snoozeCard.layer.cornerRadius=12; _snoozeCard.layer.borderWidth=1;
    _snoozeCard.onTap=^{ [ws tapSnooze]; };
    _snoozeIco=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"alarm" accessibilityDescription:nil]];
    _snoozeIco.frame=NSMakeRect((82-17)/2, 62-10-17, 17, 17); [_snoozeCard addSubview:_snoozeIco];
    _snoozeLbl=[NSTextField labelWithString:@"Snooze"];
    _snoozeLbl.font=[NSFont systemFontOfSize:10 weight:NSFontWeightMedium]; _snoozeLbl.alignment=NSTextAlignmentCenter;
    _snoozeLbl.frame=NSMakeRect(0, 62-10-17-18, 82, 14); [_snoozeCard addSubview:_snoozeLbl];
    [root addSubview:_snoozeCard];

    // Disable-for card
    _disableCard=[[VCard alloc] initWithFrame:NSMakeRect(rightX, TY(gridTop+62+8,62), 82, 62)];
    _disableCard.layer.cornerRadius=12; _disableCard.layer.borderWidth=1;
    _disableCard.onTap=^{ [ws tapDisable]; };
    _disableIco=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"nosign" accessibilityDescription:nil]];
    _disableIco.frame=NSMakeRect((82-17)/2, 62-8-17, 17, 17); [_disableCard addSubview:_disableIco];
    _disL1=[NSTextField labelWithString:@"Disable for"];
    _disL1.font=[NSFont systemFontOfSize:9.5 weight:NSFontWeightMedium]; _disL1.alignment=NSTextAlignmentCenter;
    _disL1.frame=NSMakeRect(0, 62-8-17-15, 82, 12); [_disableCard addSubview:_disL1];
    _disL2=[NSTextField labelWithString:@"Figma"];
    _disL2.font=[NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold]; _disL2.alignment=NSTextAlignmentCenter;
    _disL2.lineBreakMode=NSLineBreakByTruncatingTail;
    _disL2.frame=NSMakeRect(2, 62-8-17-15-12, 78, 12); [_disableCard addSubview:_disL2];
    [root addSubview:_disableCard];
}

// ── Quick textures ────────────────────────────────────────────────────────
- (void)buildTextures:(NSView*)root {
    NSTextField *qt=[NSTextField labelWithString:@"QUICK TEXTURES"];
    qt.font=[NSFont systemFontOfSize:9 weight:NSFontWeightBold]; qt.textColor=HEX(96,80,64);
    NSMutableAttributedString *qa=[[NSMutableAttributedString alloc] initWithString:@"QUICK TEXTURES"
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightBold],
                     NSForegroundColorAttributeName:HEX(96,80,64), NSKernAttributeName:@(0.9)}];
    qt.attributedStringValue=qa;
    qt.frame=NSMakeRect(PAD, TY(203,12), 160, 12); [root addSubview:qt];
    NSTextField *day=[NSTextField labelWithString:@"Daytime ☀"];
    day.font=[NSFont systemFontOfSize:9]; day.textColor=HEX(122,106,80); day.alignment=NSTextAlignmentRight;
    day.frame=NSMakeRect(PAD+IW-80, TY(203,12), 80, 12); [root addSubview:day];

    CGFloat cardW=floor((IW-3*7)/4.0); // 66
    __weak MenuBarPopover *ws=self;
    for (int i=0;i<4;i++) {
        CGFloat cx=PAD + i*(cardW+7);
        VCard *c=[[VCard alloc] initWithFrame:NSMakeRect(cx, TY(223,59), cardW, 59)];
        c.layer.cornerRadius=9; c.layer.borderWidth=1.5; c.layer.masksToBounds=YES;
        c.layer.backgroundColor=HEX(35,31,26).CGColor;
        int idx=i; c.onTap=^{ [ws tapTexture:idx]; };

        NSImageView *thumb=[[NSImageView alloc] initWithFrame:NSMakeRect(0, 59-42, cardW, 42)];
        thumb.imageScaling=NSImageScaleAxesIndependently; thumb.wantsLayer=YES; thumb.layer.masksToBounds=YES;
        PMColorRGB bc=PMTextureBaseRGB(kQuick[i].type);
        thumb.layer.backgroundColor=HEX(bc.r,bc.g,bc.b).CGColor;
        [c addSubview:thumb]; _texThumb[i]=thumb;

        if (kQuick[i].isNew) {
            NSTextField *nb=[NSTextField labelWithString:@"NEW"];
            nb.font=[NSFont boldSystemFontOfSize:6.5]; nb.textColor=HEX(232,204,104);
            nb.wantsLayer=YES; nb.layer.backgroundColor=HEXA(48,38,8,.92).CGColor; nb.layer.cornerRadius=3;
            nb.alignment=NSTextAlignmentCenter;
            nb.frame=NSMakeRect(3, 59-3-11, 24, 11); [c addSubview:nb];
        }
        NSView *chk=[[NSView alloc] initWithFrame:NSMakeRect(cardW-3-15, 59-3-15, 15, 15)];
        chk.wantsLayer=YES; chk.layer.cornerRadius=7.5; chk.layer.backgroundColor=HEX(200,168,64).CGColor;
        NSTextField *ck=[NSTextField labelWithString:@"✓"];
        ck.font=[NSFont boldSystemFontOfSize:8]; ck.textColor=HEX(26,20,16); ck.alignment=NSTextAlignmentCenter;
        ck.frame=NSMakeRect(0,1,15,12); [chk addSubview:ck]; chk.hidden=YES;
        [c addSubview:chk]; _texCheck[i]=chk;

        NSTextField *lbl=[NSTextField labelWithString:kShort[i]];
        lbl.font=[NSFont systemFontOfSize:8 weight:NSFontWeightMedium]; lbl.alignment=NSTextAlignmentCenter;
        lbl.textColor=HEX(154,144,128); lbl.lineBreakMode=NSLineBreakByTruncatingTail;
        lbl.wantsLayer=YES; lbl.layer.backgroundColor=HEXA(0,0,0,.22).CGColor;
        lbl.frame=NSMakeRect(0,0,cardW,59-42); [c addSubview:lbl]; _texLabel[i]=lbl;

        [root addSubview:c]; _texCards[i]=c;
    }

    VCard *all=[[VCard alloc] initWithFrame:NSMakeRect(PAD, TY(291,16), IW, 16)];
    all.onTap=^{ if (ws.onOpenSettings) ws.onOpenSettings(); };
    NSTextField *at=[NSTextField labelWithString:@"All textures  ›"];
    at.font=[NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium]; at.textColor=HEX(154,132,88);
    at.alignment=NSTextAlignmentCenter; at.frame=NSMakeRect(0,0,IW,14); [all addSubview:at];
    [root addSubview:all];
}

// ── Footer ────────────────────────────────────────────────────────────────
- (void)buildFooter:(NSView*)root {
    NSView *div=[[NSView alloc] initWithFrame:NSMakeRect(PAD-3, TY(320,1), IW+6, 1)];
    div.wantsLayer=YES; div.layer.backgroundColor=HEXA(255,255,255,.07).CGColor; [root addSubview:div];

    __weak MenuBarPopover *ws=self;
    VCard *quit=[[VCard alloc] initWithFrame:NSMakeRect(PAD, TY(332,28), 90, 28)];
    quit.onTap=^{ if (ws.onQuit) ws.onQuit(); };
    NSTextField *qt=[NSTextField labelWithString:@"Quit Vellum"];
    qt.font=[NSFont systemFontOfSize:11]; qt.textColor=HEX(96,80,64);
    qt.frame=NSMakeRect(0,(28-14)/2,90,14); [quit addSubview:qt];
    [root addSubview:quit];

    VCard *settings=[[VCard alloc] initWithFrame:NSMakeRect(PAD+IW-130, TY(331,28), 130, 28)];
    settings.layer.cornerRadius=8; settings.layer.borderWidth=1;
    settings.layer.backgroundColor=HEXA(200,168,64,.14).CGColor;
    settings.layer.borderColor=HEXA(200,168,64,.22).CGColor;
    settings.onTap=^{ if (ws.onOpenSettings) ws.onOpenSettings(); };
    NSImageView *gear=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil]];
    gear.contentTintColor=HEX(212,188,96); gear.frame=NSMakeRect(12,(28-13)/2,13,13); [settings addSubview:gear];
    NSTextField *st=[NSTextField labelWithString:@"Open Settings"];
    st.font=[NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium]; st.textColor=HEX(224,204,136);
    st.frame=NSMakeRect(31,(28-14)/2,95,14); [settings addSubview:st];
    [root addSubview:settings];
}

// ── Texture thumbnails (async) ────────────────────────────────────────────
- (void)generateThumbs {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        NSMutableArray *imgs=[NSMutableArray array];
        for (int i=0;i<4;i++) {
            NSImage *full=[PaperTextureGenerator textureForType:kQuick[i].type];
            NSImage *thumb=[[NSImage alloc] initWithSize:NSMakeSize(70,70)];
            if (full) { [thumb lockFocus];
                [full drawInRect:NSMakeRect(0,0,70,70) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
                [thumb unlockFocus]; }
            [imgs addObject:thumb];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            for (int i=0;i<4;i++) self->_texThumb[i].image=imgs[i];
        });
    });
}

// ── State refresh ─────────────────────────────────────────────────────────
- (void)refresh {
    SettingsStore *st=SettingsStore.shared;
    BOOL on=st.isEnabled, snooze=st.isSnoozed, live=on&&!snooze;

    // toggle card
    if (live) {
        _toggleCard.layer.backgroundColor=HEXA(200,168,64,.12).CGColor;
        _toggleCard.layer.borderColor=HEXA(200,168,64,.30).CGColor;
    } else {
        _toggleCard.layer.backgroundColor=HEXA(0,0,0,.24).CGColor;
        _toggleCard.layer.borderColor=HEXA(255,255,255,.06).CGColor;
    }
    [self setOrbLive:live];
    NSString *ts = snooze?@"Snoozed · 20 min left":on?[NSString stringWithFormat:@"On · %@",PMTextureName(st.selectedTexture)]:@"Protection off";
    _toggleStatus.stringValue=ts;
    _toggleStatus.textColor=live?HEX(168,146,94):snooze?HEX(154,132,88):HEX(112,94,72);

    // intensity
    _slider.doubleValue=st.intensity;
    _intPct.stringValue=[NSString stringWithFormat:@"%d%%",(int)(st.intensity*100)];

    // snooze / disable card states
    [self styleCard:_snoozeCard active:snooze];
    _snoozeIco.contentTintColor=snooze?HEX(224,204,120):HEX(154,138,116);
    _snoozeLbl.stringValue=snooze?@"Snoozed":@"Snooze";
    _snoozeLbl.textColor=snooze?HEX(224,204,120):HEX(154,138,116);

    BOOL excluded = _targetBundleId.length && [st isAppExcluded:_targetBundleId];
    [self styleCard:_disableCard active:excluded];
    _disableIco.contentTintColor=excluded?HEX(224,204,120):HEX(154,138,116);
    _disL1.textColor=excluded?HEX(224,204,120):HEX(154,138,116);
    _disL2.textColor=excluded?HEX(224,204,120):HEX(154,138,116);
    _disL2.stringValue=_targetAppName.length?_targetAppName:@"frontmost app";

    // texture selection
    for (int i=0;i<4;i++) {
        BOOL sel=(kQuick[i].type==st.selectedTexture);
        _texCards[i].layer.borderColor=(sel?HEX(200,168,64):HEXA(255,255,255,.08)).CGColor;
        _texCheck[i].hidden=!sel;
        _texLabel[i].textColor=sel?HEX(212,188,96):HEX(154,144,128);
    }
}

- (void)styleCard:(VCard*)c active:(BOOL)a {
    c.layer.backgroundColor=(a?HEXA(200,168,64,.14):HEXA(0,0,0,.24)).CGColor;
    c.layer.borderColor=(a?HEXA(200,168,64,.30):HEXA(255,255,255,.06)).CGColor;
}

// vmGlow: pulsing gold halo when live; grayscale(.85) brightness(.6) when off.
- (void)setOrbLive:(BOOL)live {
    if (live) {
        _orb.alphaValue=1.0; _orb.layer.filters=nil;
        if (![_orbWrap.layer animationForKey:@"vmGlow"]) {
            _orbWrap.layer.shadowOpacity=0.32; _orbWrap.layer.shadowRadius=21;
            CABasicAnimation *r=[CABasicAnimation animationWithKeyPath:@"shadowRadius"];
            r.fromValue=@16; r.toValue=@26;
            CABasicAnimation *o=[CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
            o.fromValue=@0.22; o.toValue=@0.42;
            CAAnimationGroup *g=[CAAnimationGroup animation];
            g.animations=@[r,o]; g.duration=1.7; g.autoreverses=YES; g.repeatCount=HUGE_VALF;
            g.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [_orbWrap.layer addAnimation:g forKey:@"vmGlow"];
        }
    } else {
        [_orbWrap.layer removeAnimationForKey:@"vmGlow"];
        _orbWrap.layer.shadowOpacity=0; _orb.alphaValue=0.85;
        CIFilter *f=[CIFilter filterWithName:@"CIColorControls"];
        [f setValue:@0.15 forKey:@"inputSaturation"];
        [f setValue:@(-0.12) forKey:@"inputBrightness"];
        _orb.layer.filters=@[f];
    }
}

// ── Actions ───────────────────────────────────────────────────────────────
- (void)tapToggle {
    SettingsStore *st=SettingsStore.shared;
    BOOL newOn=!st.isEnabled;
    st.isEnabled=newOn;
    if (newOn) { st.isSnoozed=NO; [OverlayManager.shared enable]; }
    else { [OverlayManager.shared disable]; }
    [self refresh];
}
- (void)tapSnooze {
    SettingsStore *st=SettingsStore.shared;
    if (!st.isEnabled) return;
    [OverlayManager.shared setSnooze:!st.isSnoozed];
    [self refresh];
}
- (void)tapDisable {
    if (!_targetBundleId.length) return;
    [SettingsStore.shared toggleExclusionForApp:_targetBundleId];
    [OverlayManager.shared updateVisibilityForFocusedApp];
    [self refresh];
}
- (void)sliderChanged:(NSSlider*)s {
    SettingsStore *st=SettingsStore.shared;
    st.intensity=s.doubleValue; st.isEnabled=YES; st.isSnoozed=NO;
    _intPct.stringValue=[NSString stringWithFormat:@"%d%%",(int)(s.doubleValue*100)];
    if (!OverlayManager.shared.isActive) [OverlayManager.shared enable];
    else [OverlayManager.shared update];
    [self refresh];
}
- (void)tapTexture:(int)i {
    SettingsStore *st=SettingsStore.shared;
    st.selectedTexture=kQuick[i].type;
    st.intensity=kQuick[i].def;
    st.isEnabled=YES; st.isSnoozed=NO;
    if (!OverlayManager.shared.isActive) [OverlayManager.shared enable];
    else [OverlayManager.shared update];
    [self refresh];
}

@end
