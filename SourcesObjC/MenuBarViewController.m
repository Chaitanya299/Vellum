#import "MenuBarViewController.h"
#import "SettingsStore.h"
#import "OverlayManager.h"
#import "AppManager.h"
#import "TextureType.h"
#import "PaperTextureGenerator.h"
#import "VellumIcon.h"

// ── Exact design colors ───────────────────────────────────────────────────
static NSColor *HEX(CGFloat r,CGFloat g,CGFloat b){ return [NSColor colorWithSRGBRed:r/255 green:g/255 blue:b/255 alpha:1]; }
static NSColor *HEXA(CGFloat r,CGFloat g,CGFloat b,CGFloat a){ return [NSColor colorWithSRGBRed:r/255 green:g/255 blue:b/255 alpha:a]; }

// ── Layout constants ──────────────────────────────────────────────────────
#define WIN_W  610.0
#define WIN_H  475.0
#define SIDE_W 158.0
#define CONT_W 452.0
#define PAD_H   28.0
#define PAD_V   26.0

// ── NSView coordinate helpers (y=0 at visual BOTTOM) ─────────────────────
// PY: design "vtop from panel top" + element height → NSView y from bottom (panel height = WIN_H)
#define PY(vtop,h)     (WIN_H-(vtop)-(h))
// BOTY: same but for an arbitrary-height container H
#define BOTY(H,vtop,h) ((H)-(vtop)-(h))

// ── Layer-backed base for custom-drawing leaf views.
// On the macOS 26 beta, non-layer-backed custom NSView subclasses are laid out
// inconsistently inside springs-and-struts parents; forcing a backing layer makes
// frame positioning behave like the (working) layer-backed plain views. ──────
@interface PECV : NSView
@end
@implementation PECV
- (instancetype)initWithFrame:(NSRect)f {
    self = [super initWithFrame:f];
    if (self) self.wantsLayer = YES;
    return self;
}
@end

// ── Separator line ────────────────────────────────────────────────────────
@interface PESep : NSView
@end
@implementation PESep
- (void)drawRect:(NSRect)r { [HEXA(255,255,255,.055) setFill]; NSRectFill(r); }
@end

// ── Nav row ───────────────────────────────────────────────────────────────
@interface PENavRow : PECV
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, copy)   NSString *label;
@property (nonatomic, copy)   NSString *sym;
@property (nonatomic, copy)   void (^onTap)(void);
@end
@implementation PENavRow {
    NSView *_circle; NSImageView *_icon; NSTextField *_text;
}
- (instancetype)initWithFrame:(NSRect)f {
    self=[super initWithFrame:f]; // PECV → wantsLayer=YES
    if (self) {
        self.layer.cornerRadius=7;
        CGFloat h=NSHeight(f);
        _circle=[[NSView alloc] initWithFrame:NSMakeRect(10,(h-24)/2,24,24)];
        _circle.wantsLayer=YES; _circle.layer.cornerRadius=12; _circle.layer.borderWidth=1;
        [self addSubview:_circle];
        _icon=[[NSImageView alloc] initWithFrame:NSMakeRect(16,(h-13)/2,13,13)];
        [self addSubview:_icon];
        _text=[NSTextField labelWithString:@""];
        _text.frame=NSMakeRect(43,(h-16)/2,NSWidth(f)-50,16);
        [self addSubview:_text];
    }
    return self;
}
- (void)setSym:(NSString*)s { _sym=[s copy]; _icon.image=[NSImage imageWithSystemSymbolName:s accessibilityDescription:nil]; [self apply]; }
- (void)setIconIdx:(NSInteger)i { _icon.image=[VellumIcon sidebarIconAtIndex:i size:_icon.frame.size.width]; [self apply]; }
- (void)setLabel:(NSString*)l { _label=[l copy]; _text.stringValue=l?:@""; [self apply]; }
- (void)setSelected:(BOOL)s { _selected=s; [self apply]; }
- (void)apply {
    self.layer.backgroundColor=(_selected?HEXA(200,168,64,.20):NSColor.clearColor).CGColor;
    _circle.layer.backgroundColor=(_selected?HEXA(200,168,64,.18):HEXA(255,255,255,.07)).CGColor;
    _circle.layer.borderColor=(_selected?NSColor.clearColor:HEXA(255,255,255,.09)).CGColor;
    _icon.contentTintColor=(_selected?HEX(212,188,96):HEX(96,80,72));
    _text.font=[NSFont systemFontOfSize:13 weight:(_selected?NSFontWeightMedium:NSFontWeightRegular)];
    _text.textColor=(_selected?HEX(213,210,197):HEX(122,106,88));
}
- (void)mouseUp:(NSEvent *)e {
    if (NSPointInRect([self convertPoint:e.locationInWindow fromView:nil],self.bounds)&&_onTap) _onTap();
}
- (BOOL)acceptsFirstMouse:(NSEvent*)e { return YES; }
@end

// ── Clickable button ──────────────────────────────────────────────────────
@interface PEBtn : PECV
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, assign) BOOL primary;
@property (nonatomic, assign) BOOL lit;
@property (nonatomic, copy)   void (^onTap)(void);
@end
@implementation PEBtn {
    NSTextField *_text;
}
- (instancetype)initWithFrame:(NSRect)f {
    self=[super initWithFrame:f]; // PECV → wantsLayer=YES
    if (self) {
        self.layer.cornerRadius=8; self.layer.borderWidth=1;
        _text=[NSTextField labelWithString:@""];
        _text.alignment=NSTextAlignmentCenter;
        _text.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        _text.frame=NSMakeRect(0,(NSHeight(f)-16)/2,NSWidth(f),16);
        [self addSubview:_text];
    }
    return self;
}
- (void)setTitle:(NSString*)t { _title=[t copy]; _text.stringValue=t?:@""; }
- (void)setPrimary:(BOOL)p { _primary=p; [self apply]; }
- (void)apply {
    if (_primary) {
        self.layer.backgroundColor=(_lit?HEXA(70,54,16,1):HEX(50,40,10)).CGColor;
        self.layer.borderColor=HEXA(200,168,64,.25).CGColor;
        _text.textColor=HEX(212,188,96);
    } else {
        self.layer.backgroundColor=(_lit?HEXA(255,255,255,.12):HEXA(255,255,255,.07)).CGColor;
        self.layer.borderColor=HEXA(255,255,255,.08).CGColor;
        _text.textColor=HEX(122,106,88);
    }
}
- (void)mouseDown:(NSEvent*)e { _lit=YES; [self apply]; }
- (void)mouseUp:(NSEvent*)e {
    _lit=NO; [self apply];
    if (NSPointInRect([self convertPoint:e.locationInWindow fromView:nil],self.bounds)&&_onTap) _onTap();
}
- (BOOL)acceptsFirstMouse:(NSEvent*)e { return YES; }
@end

// ── Tab button ────────────────────────────────────────────────────────────
@interface PETab : PECV
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, copy)   void (^onTap)(void);
@end
@implementation PETab {
    NSTextField *_text;
}
- (instancetype)initWithFrame:(NSRect)f {
    self=[super initWithFrame:f]; // PECV → wantsLayer=YES
    if (self) {
        self.layer.cornerRadius=6;
        _text=[NSTextField labelWithString:@""];
        _text.alignment=NSTextAlignmentCenter;
        _text.font=[NSFont systemFontOfSize:12.5 weight:NSFontWeightMedium];
        _text.frame=NSMakeRect(0,(NSHeight(f)-15)/2,NSWidth(f),15);
        [self addSubview:_text];
    }
    return self;
}
- (void)setTitle:(NSString*)t { _title=[t copy]; _text.stringValue=t?:@""; }
- (void)setActive:(BOOL)a {
    _active=a;
    self.layer.backgroundColor=(a?HEX(50,40,10):NSColor.clearColor).CGColor;
    _text.textColor=(a?HEX(213,210,197):HEX(96,80,64));
}
- (void)mouseUp:(NSEvent*)e {
    if (NSPointInRect([self convertPoint:e.locationInWindow fromView:nil],self.bounds)&&_onTap) _onTap();
}
- (BOOL)acceptsFirstMouse:(NSEvent*)e { return YES; }
@end

// ── Texture card — NSView (y=0 at visual BOTTOM) ──────────────────────────
// thumb=62px occupies top of card; label=24px occupies bottom.
// In NSView: thumb at y=LH..LH+TH, label at y=0..LH
@interface PETexCard : PECV
@property (nonatomic, assign) PMTextureType texType;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, copy)   NSString *badge;
@property (nonatomic, strong) NSImage *thumbImg;
@property (nonatomic, copy)   void (^onTap)(void);
@end
@implementation PETexCard {
    NSImageView *_thumb; NSView *_labelBg; NSTextField *_name;
    NSView *_badgeBg; NSTextField *_badgeLbl;
    NSView *_checkBg; NSTextField *_checkLbl;
}
- (instancetype)initWithFrame:(NSRect)f {
    self=[super initWithFrame:f]; // PECV → wantsLayer=YES
    if (self) {
        const CGFloat TH=62, LH=NSHeight(f)-TH, w=NSWidth(f);
        self.layer.cornerRadius=8; self.layer.masksToBounds=YES;
        self.layer.backgroundColor=HEX(36,56,32).CGColor;
        self.layer.borderWidth=1.5;
        // Thumb (top), shows base color then texture image
        _thumb=[[NSImageView alloc] initWithFrame:NSMakeRect(0,LH,w,TH)];
        _thumb.wantsLayer=YES; _thumb.imageScaling=NSImageScaleAxesIndependently;
        [self addSubview:_thumb];
        // Label area (bottom)
        _labelBg=[[NSView alloc] initWithFrame:NSMakeRect(0,0,w,LH)];
        _labelBg.wantsLayer=YES; _labelBg.layer.backgroundColor=HEXA(0,0,0,.18).CGColor;
        [self addSubview:_labelBg];
        _name=[NSTextField labelWithString:@""];
        _name.font=[NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
        _name.textColor=HEX(176,173,160);
        _name.frame=NSMakeRect(7,(LH-14)/2,w-14,14);
        [self addSubview:_name];
        // Badge pill (thumb top-left)
        _badgeBg=[[NSView alloc] initWithFrame:NSMakeRect(5,NSHeight(f)-5-14,40,14)];
        _badgeBg.wantsLayer=YES; _badgeBg.layer.cornerRadius=4;
        _badgeBg.layer.backgroundColor=HEXA(50,40,8,.92).CGColor; _badgeBg.hidden=YES;
        _badgeLbl=[NSTextField labelWithString:@""];
        _badgeLbl.font=[NSFont boldSystemFontOfSize:7.5]; _badgeLbl.textColor=HEX(212,188,96);
        _badgeLbl.frame=NSMakeRect(5,0,30,14);
        [_badgeBg addSubview:_badgeLbl]; [self addSubview:_badgeBg];
        // Checkmark circle (thumb top-right)
        _checkBg=[[NSView alloc] initWithFrame:NSMakeRect(w-22,NSHeight(f)-5-17,17,17)];
        _checkBg.wantsLayer=YES; _checkBg.layer.cornerRadius=8.5;
        _checkBg.layer.backgroundColor=HEX(200,168,64).CGColor; _checkBg.hidden=YES;
        _checkLbl=[NSTextField labelWithString:@"✓"];
        _checkLbl.font=[NSFont boldSystemFontOfSize:9]; _checkLbl.textColor=NSColor.whiteColor;
        _checkLbl.alignment=NSTextAlignmentCenter; _checkLbl.frame=NSMakeRect(0,1,17,14);
        [_checkBg addSubview:_checkLbl]; [self addSubview:_checkBg];
        [self apply];
    }
    return self;
}
- (void)setTexType:(PMTextureType)t {
    _texType=t;
    PMColorRGB c=PMTextureBaseRGB(t);
    _thumb.layer.backgroundColor=HEX(c.r,c.g,c.b).CGColor;
    _name.stringValue=PMTextureName(t);
}
- (void)setThumbImg:(NSImage*)i { _thumbImg=i; _thumb.image=i; }
- (void)setBadge:(NSString*)b {
    _badge=[b copy];
    if (b.length) {
        _badgeLbl.stringValue=b;
        NSSize bs=[b sizeWithAttributes:@{NSFontAttributeName:_badgeLbl.font}];
        _badgeBg.frame=NSMakeRect(5,NSHeight(self.frame)-5-14,bs.width+10,14);
        _badgeLbl.frame=NSMakeRect(5,0,bs.width+2,14);
        _badgeBg.hidden=NO;
    } else _badgeBg.hidden=YES;
}
- (void)setSelected:(BOOL)v { _selected=v; [self apply]; }
- (void)apply {
    _checkBg.hidden=!_selected;
    self.layer.borderColor=(_selected?HEX(200,168,64):HEXA(255,255,255,.07)).CGColor;
}
- (void)mouseUp:(NSEvent*)e {
    if (NSPointInRect([self convertPoint:e.locationInWindow fromView:nil],self.bounds)&&_onTap) _onTap();
}
- (BOOL)acceptsFirstMouse:(NSEvent*)e { return YES; }
@end

// ── Main VC ───────────────────────────────────────────────────────────────
@interface MenuBarViewController () {
    NSView *_panels[6];
}
@property (nonatomic, strong) NSArray<PENavRow*>  *navRows;
@property (nonatomic, assign) NSInteger            activeNav;
// Protection panel
@property (nonatomic, strong) PEBtn               *onBtn;
@property (nonatomic, strong) PEBtn               *snoozeBtn;
@property (nonatomic, strong) NSTextField         *statusTxt;
@property (nonatomic, strong) NSTextField         *activeTexTxt;
@property (nonatomic, strong) NSTextField         *intensityTxt;
@property (nonatomic, strong) NSTextField         *intensityPct;
@property (nonatomic, strong) NSSlider            *intensitySlider;
// Textures panel
@property (nonatomic, strong) NSMutableArray<PETexCard*> *texCards;
@property (nonatomic, strong) NSMutableArray<NSImage*>   *thumbImgs;
@property (nonatomic, strong) PETab               *tabDay;
@property (nonatomic, strong) PETab               *tabNight;
@property (nonatomic, strong) NSTextField         *tabLabel;
@property (nonatomic, assign) NSInteger            texTab;
@property (nonatomic, strong) NSView              *texGrid;
// Exceptions panel
@property (nonatomic, strong) NSComboBox          *exField;
@property (nonatomic, strong) NSView              *exList;
@property (nonatomic, strong) NSScrollView        *exScroll;
@property (nonatomic, strong) NSArray<AppInfo*>   *allApps;
@end

@implementation MenuBarViewController

- (void)loadView {
    _allApps = [AppManager installedApplications];
    _activeNav = 0;
    _texTab = 0;
    _texCards = [NSMutableArray array];
    _thumbImgs = [NSMutableArray array];

    NSView *root=[[NSView alloc] initWithFrame:NSMakeRect(0,0,WIN_W,WIN_H)];
    root.wantsLayer=YES;
    root.layer.backgroundColor=HEX(26,24,22).CGColor;
    [self buildSidebar:root];
    [self buildContent:root];
    self.view=root;
    [self updateProtectionUI];
    [self generateTextures];
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Sidebar  (NSView, y=0 at visual BOTTOM)
// ─────────────────────────────────────────────────────────────────────────
- (void)buildSidebar:(NSView*)root {
    NSView *side=[[NSView alloc] initWithFrame:NSMakeRect(0,0,SIDE_W,WIN_H)];
    side.wantsLayer=YES; side.layer.backgroundColor=HEX(20,18,16).CGColor;

    // ── Vellum logo lockup (from PaperEye Logo.dc.html): orb + wordmark + tagline ──
    NSImageView *orb=[NSImageView imageViewWithImage:[VellumIcon iconWithSize:56]];
    orb.frame=NSMakeRect(14, PY(15,28), 28, 28);
    orb.wantsLayer=YES; orb.layer.cornerRadius=7; orb.layer.masksToBounds=YES;
    [side addSubview:orb];

    // "Vellum" — Cormorant Garamond SemiBold (bundled), elegant fallbacks.
    NSFont *word=[NSFont fontWithName:@"CormorantGaramond-SemiBold" size:24]
                 ?: [NSFont fontWithName:@"Hoefler Text" size:22]
                 ?: [NSFont fontWithName:@"Didot" size:21]
                 ?: [NSFont systemFontOfSize:21 weight:NSFontWeightSemibold];
    NSTextField *mark=[NSTextField labelWithString:@"Vellum"];
    mark.font=word; mark.textColor=HEX(239,230,210); // #EFE6D2
    [mark sizeToFit];
    CGFloat mh=mark.frame.size.height;
    mark.frame=NSMakeRect(48, PY(14,mh), SIDE_W-54, mh);
    [side addSubview:mark];

    // "EASE THE LIGHT" tagline — gold, letter-spaced, uppercase.
    NSDictionary *tatt=@{NSFontAttributeName:[NSFont systemFontOfSize:8 weight:NSFontWeightMedium],
                         NSForegroundColorAttributeName:HEX(138,106,68), // #8A6A44
                         NSKernAttributeName:@(1.6)};
    NSTextField *tag=[NSTextField labelWithAttributedString:
                      [[NSAttributedString alloc] initWithString:@"EASE THE LIGHT" attributes:tatt]];
    tag.frame=NSMakeRect(49, PY(43,11), SIDE_W-54, 11);
    [side addSubview:tag];

    // Separator below the lockup
    PESep *sep1=[[PESep alloc] initWithFrame:NSMakeRect(14, PY(64,1), SIDE_W-28, 1)];
    [side addSubview:sep1];

    // Nav rows: design top=52+i*38, h=36
    NSArray *labels=@[@"Protection",@"Textures",@"Circadian Rhythm",@"Display",@"Exceptions",@"License"];
    NSMutableArray *rows=[NSMutableArray array];
    for (NSInteger i=0;i<6;i++) {
        CGFloat rowTop=74+i*38;
        PENavRow *row=[[PENavRow alloc] initWithFrame:NSMakeRect(8, PY(rowTop,36), SIDE_W-16, 36)];
        row.label=labels[i]; [row setIconIdx:i]; row.selected=(i==0);
        NSInteger cap=i; __weak MenuBarViewController *ws=self;
        row.onTap=^{ [ws switchNav:cap]; };
        [side addSubview:row]; [rows addObject:row];
    }
    _navRows=rows;

    // Bottom sep: design top=WIN_H-34, h=1
    PESep *bsep=[[PESep alloc] initWithFrame:NSMakeRect(0, PY(WIN_H-34,1), SIDE_W, 1)];
    [side addSubview:bsep];
    NSTextField *reset=[NSTextField labelWithString:@"Reset to defaults"];
    reset.font=[NSFont systemFontOfSize:11]; reset.textColor=HEX(74,60,48);
    reset.frame=NSMakeRect(14, PY(WIN_H-25,14), SIDE_W-20, 14);
    [side addSubview:reset];

    // Right divider (vertical, full height — frame is coordinate-independent)
    PESep *rdiv=[[PESep alloc] initWithFrame:NSMakeRect(SIDE_W-1,0,1,WIN_H)];
    [side addSubview:rdiv];

    [root addSubview:side];
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Content area
// ─────────────────────────────────────────────────────────────────────────
- (void)buildContent:(NSView*)root {
    NSArray *panels=@[
        [self buildProtection],
        [self buildTextures],
        [self buildCircadian],
        [self buildDisplay],
        [self buildExceptions],
        [self buildLicense]
    ];
    for (NSInteger i=0;i<6;i++) {
        NSView *panel=panels[i];
        panel.frame=NSMakeRect(SIDE_W,0,CONT_W,WIN_H);
        panel.hidden=(i!=0);
        [root addSubview:panel];
        _panels[i]=panel;
    }
}

- (void)switchNav:(NSInteger)idx {
    if (_activeNav==idx) return;
    _panels[_activeNav].hidden=YES;
    [_navRows[_activeNav] setSelected:NO];
    _activeNav=idx;
    _panels[idx].hidden=NO;
    [_navRows[idx] setSelected:YES];
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 0: Protection  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildProtection {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    SettingsStore *st=SettingsStore.shared;
    CGFloat lx=PAD_V;

    // Eye circle: design top=28, h=50
    NSView *eyeCircle=[[NSView alloc] initWithFrame:NSMakeRect(lx, PY(28,50), 50, 50)];
    eyeCircle.wantsLayer=YES; eyeCircle.layer.cornerRadius=25;
    eyeCircle.layer.backgroundColor=HEXA(200,168,64,.12).CGColor;
    eyeCircle.layer.borderWidth=1.5;
    eyeCircle.layer.borderColor=HEXA(200,168,64,.35).CGColor;
    NSTextField *eyeIco=[NSTextField labelWithString:@"👁"];
    eyeIco.font=[NSFont systemFontOfSize:20]; [eyeIco sizeToFit];
    // Centered inside 50×50 — symmetric formula works in either orientation
    eyeIco.frame=NSMakeRect((50-eyeIco.frame.size.width)/2,(50-eyeIco.frame.size.height)/2,
                            eyeIco.frame.size.width, eyeIco.frame.size.height);
    [eyeCircle addSubview:eyeIco];
    [p addSubview:eyeCircle];

    // Title: design top=28, h=22
    NSTextField *title=[NSTextField labelWithString:@"Protection"];
    title.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
    title.textColor=HEX(226,222,209);
    title.frame=NSMakeRect(lx+50+13, PY(28,22), CONT_W-lx-50-13-lx, 22);
    [p addSubview:title];

    // Status: design top=53, h=18
    _statusTxt=[NSTextField labelWithString:@""];
    _statusTxt.font=[NSFont systemFontOfSize:12.5]; _statusTxt.textColor=HEX(200,168,64);
    _statusTxt.frame=NSMakeRect(lx+50+13, PY(53,18), CONT_W-lx-50-13-lx, 18);
    [p addSubview:_statusTxt];

    // Buttons: design top=100, h=34
    _onBtn=[[PEBtn alloc] initWithFrame:NSMakeRect(lx, PY(100,34), 95, 34)];
    _onBtn.primary=st.isEnabled;
    __weak MenuBarViewController *ws=self;
    _onBtn.onTap=^{ [ws tapOn]; };
    [p addSubview:_onBtn];

    _snoozeBtn=[[PEBtn alloc] initWithFrame:NSMakeRect(lx+95+8, PY(100,34), 86, 34)];
    _snoozeBtn.primary=NO;
    _snoozeBtn.onTap=^{ [ws tapSnooze]; };
    [p addSubview:_snoozeBtn];

    // Info box: design top=154, h=76
    CGFloat boxW=CONT_W-2*lx;
    NSView *infoBox=[[NSView alloc] initWithFrame:NSMakeRect(lx, PY(154,76), boxW, 76)];
    infoBox.wantsLayer=YES; infoBox.layer.cornerRadius=10;
    infoBox.layer.backgroundColor=HEXA(0,0,0,.20).CGColor;
    infoBox.layer.borderWidth=1; infoBox.layer.borderColor=HEXA(255,255,255,.06).CGColor;
    // NSView infoBox (h=76): "Active Texture" label at design top=12, h=12
    NSTextField *atLabel=[NSTextField labelWithString:@"Active Texture"];
    atLabel.font=[NSFont systemFontOfSize:9.5 weight:NSFontWeightBold];
    atLabel.textColor=HEX(80,64,56);
    atLabel.frame=NSMakeRect(16, BOTY(76,12,12), boxW-32, 12);
    [infoBox addSubview:atLabel];
    // Texture name: design top=29, h=18 → BOTY(76,29,18)=29
    _activeTexTxt=[NSTextField labelWithString:PMTextureName(st.selectedTexture)];
    _activeTexTxt.font=[NSFont systemFontOfSize:13.5 weight:NSFontWeightMedium];
    _activeTexTxt.textColor=HEX(208,203,192);
    _activeTexTxt.frame=NSMakeRect(16, BOTY(76,29,18), boxW-32, 18);
    [infoBox addSubview:_activeTexTxt];
    // Intensity line: design top=50, h=14 → BOTY(76,50,14)=12
    _intensityTxt=[NSTextField labelWithString:[NSString stringWithFormat:@"Intensity %d%%",(int)(st.intensity*100)]];
    _intensityTxt.font=[NSFont systemFontOfSize:11]; _intensityTxt.textColor=HEX(97,128,86);
    _intensityTxt.frame=NSMakeRect(16, BOTY(76,50,14), boxW-32, 14);
    [infoBox addSubview:_intensityTxt];
    [p addSubview:infoBox];

    // Intensity label: design top=250, h=16
    NSTextField *intTitle=[NSTextField labelWithString:@"Intensity"];
    intTitle.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    intTitle.textColor=HEX(122,106,88);
    intTitle.frame=NSMakeRect(lx, PY(250,16), 80, 16);
    [p addSubview:intTitle];

    _intensityPct=[NSTextField labelWithString:[NSString stringWithFormat:@"%d%%",(int)(st.intensity*100)]];
    _intensityPct.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    _intensityPct.alignment=NSTextAlignmentRight; _intensityPct.textColor=HEX(122,106,88);
    _intensityPct.frame=NSMakeRect(CONT_W-lx-40, PY(250,16), 40, 16);
    [p addSubview:_intensityPct];

    // Slider: design top=273, h=20
    _intensitySlider=[[NSSlider alloc] initWithFrame:NSMakeRect(lx, PY(273,20), CONT_W-2*lx, 20)];
    _intensitySlider.minValue=0.05; _intensitySlider.maxValue=1.0;
    _intensitySlider.doubleValue=st.intensity; _intensitySlider.continuous=YES;
    _intensitySlider.target=self; _intensitySlider.action=@selector(sliderChanged:);
    [p addSubview:_intensitySlider];

    // Subtle/Strong: design top=297, h=13
    NSTextField *subtle=[NSTextField labelWithString:@"Subtle"];
    subtle.font=[NSFont systemFontOfSize:9.5]; subtle.textColor=HEX(80,64,56);
    subtle.frame=NSMakeRect(lx, PY(297,13), 50, 13); [p addSubview:subtle];
    NSTextField *strong=[NSTextField labelWithString:@"Strong"];
    strong.font=[NSFont systemFontOfSize:9.5]; strong.textColor=HEX(80,64,56);
    strong.alignment=NSTextAlignmentRight;
    strong.frame=NSMakeRect(CONT_W-lx-50, PY(297,13), 50, 13); [p addSubview:strong];

    return p;
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 1: Textures  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildTextures {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    CGFloat lx=24;
    // design y accumulates from top (for computing PY at each element)
    CGFloat y=26;

    // Title: design top=26, h=22
    NSTextField *ttl=[NSTextField labelWithString:@"Texture Presets"];
    ttl.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold]; ttl.textColor=HEX(226,222,209);
    ttl.frame=NSMakeRect(lx, PY(y,22), CONT_W-2*lx, 22); [p addSubview:ttl]; y+=22+4; // y=52

    // Subtitle: design top=52, h=32
    NSTextField *sub=[NSTextField labelWithString:@"Pick a texture for each theme. Adjust intensity from the menu bar."];
    sub.font=[NSFont systemFontOfSize:12]; sub.textColor=HEX(112,96,80);
    sub.lineBreakMode=NSLineBreakByWordWrapping;
    sub.frame=NSMakeRect(lx, PY(y,32), CONT_W-2*lx, 32); [p addSubview:sub]; y+=32+16; // y=100

    // Tab container: design top=100, h=30
    NSView *tabBg=[[NSView alloc] initWithFrame:NSMakeRect(lx, PY(y,30), 210, 30)];
    tabBg.wantsLayer=YES; tabBg.layer.cornerRadius=9;
    tabBg.layer.backgroundColor=HEXA(0,0,0,.30).CGColor;
    __weak MenuBarViewController *ws=self;
    // Tabs inside tabBg (30px): at y=3, h=24 → BOTY(30,3,24)=3 (symmetric)
    _tabDay=[[PETab alloc] initWithFrame:NSMakeRect(3,3,98,24)];
    _tabDay.title=@"☀ Daytime"; _tabDay.active=(_texTab==0);
    _tabDay.onTap=^{ [ws switchTexTab:0]; }; [tabBg addSubview:_tabDay];
    _tabNight=[[PETab alloc] initWithFrame:NSMakeRect(105,3,99,24)];
    _tabNight.title=@"◑ Nighttime"; _tabNight.active=(_texTab==1);
    _tabNight.onTap=^{ [ws switchTexTab:1]; }; [tabBg addSubview:_tabNight];
    [p addSubview:tabBg]; y+=30+14; // y=144

    // Label row: design top=144, h=13
    _tabLabel=[NSTextField labelWithString:@"TEXTURE IN DAYTIME MODE"];
    _tabLabel.font=[NSFont systemFontOfSize:9.5 weight:NSFontWeightBold];
    _tabLabel.textColor=HEX(80,64,56);
    _tabLabel.frame=NSMakeRect(lx, PY(y,13), CONT_W-2*lx-60, 13); [p addSubview:_tabLabel];
    NSTextField *countLbl=[NSTextField labelWithString:@"◆ 9/9"];
    countLbl.font=[NSFont systemFontOfSize:9.5]; countLbl.textColor=HEX(80,64,56);
    countLbl.alignment=NSTextAlignmentRight;
    countLbl.frame=NSMakeRect(CONT_W-lx-60, PY(y,13), 60, 13); [p addSubview:countLbl];
    y+=13+9; // y=166

    // Grid: initial frame at design top=166 (NSView y = WIN_H-166 = 309).
    // Height starts 0; rebuildTexGrid sets the real height and adjusts origin.y downward.
    CGFloat gridW=CONT_W-2*lx;
    _texGrid=[[NSView alloc] initWithFrame:NSMakeRect(lx, WIN_H-y, gridW, 0)];
    [p addSubview:_texGrid];
    [self rebuildTexGrid];

    return p;
}

- (void)rebuildTexGrid {
    for (NSView *v in [_texGrid.subviews copy]) [v removeFromSuperview];
    [_texCards removeAllObjects];

    NSInteger dayIdx[9]={0,1,2,3,4,5,6,7,8};
    NSInteger nightIdx[3]={9,10,11};
    NSInteger *idxArr=(_texTab==0)?dayIdx:nightIdx;
    NSInteger count=(_texTab==0)?9:3;
    NSArray *badges=@[@"RECOMMENDED",@"",@"NEW",@"",@"",@"",@"",@"",@""];

    CGFloat gW=_texGrid.frame.size.width;
    CGFloat cardW=floor((gW-14)/3.0); // 3 cols, 2×7 gaps
    CGFloat cardH=62+24; // 86px
    NSInteger rows=(count+2)/3;
    CGFloat gridH=rows*(cardH+7)-7;

    // Grid top in panel = design y=166 → NSView origin.y = WIN_H-166-gridH = 309-gridH
    _texGrid.frame=NSMakeRect(_texGrid.frame.origin.x, 309-gridH, gW, gridH);

    // Cards: row r=0 is visually at the TOP of the grid.
    // NSView grid (y=0 at bottom): row r origin.y = gridH - r*(cardH+7) - cardH
    for (NSInteger r=0;r<rows;r++) {
        CGFloat cardy=gridH-r*(cardH+7)-cardH;
        for (NSInteger c=0;c<3;c++) {
            NSInteger li=r*3+c;
            if (li>=count) break;
            PMTextureType type=(PMTextureType)idxArr[li];
            NSRect fr=NSMakeRect(c*(cardW+7), cardy, cardW, cardH);
            PETexCard *card=[[PETexCard alloc] initWithFrame:fr];
            card.texType=type;
            card.selected=(type==SettingsStore.shared.selectedTexture);
            card.badge=(_texTab==0&&li<(NSInteger)badges.count)?badges[li]:@"";
            if ((NSInteger)_thumbImgs.count>type) card.thumbImg=_thumbImgs[type];
            __weak MenuBarViewController *ws2=self;
            PMTextureType capType=type;
            card.onTap=^{ [ws2 pickTexture:capType]; };
            [_texGrid addSubview:card];
            [_texCards addObject:card];
        }
    }
}

- (void)switchTexTab:(NSInteger)tab {
    _texTab=tab;
    _tabDay.active=(tab==0); _tabNight.active=(tab==1);
    _tabLabel.stringValue=(tab==0)?@"TEXTURE IN DAYTIME MODE":@"TEXTURE IN NIGHTTIME MODE";
    [self rebuildTexGrid];
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 2: Circadian Rhythm  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildCircadian {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    CGFloat y=PAD_H; CGFloat lx=PAD_V;
    [self panelTitle:p text:@"Circadian Rhythm" y:&y lx:lx]; // y→54
    [self panelSub:p text:@"Automatically switch textures based on the time of day." y:&y lx:lx]; // y→98

    CGFloat bw=CONT_W-2*lx;

    // Enable Schedule row: design top=98, h=52
    NSView *row=[self roundBox:NSMakeRect(lx, PY(y,52), bw, 52)]; y+=52+12; // y→162
    [self rowTitle:row t:@"Enable Schedule" s:@"Auto-switch at sunrise and sunset" greenSub:YES boxH:52];
    NSSwitch *sw=[[NSSwitch alloc] initWithFrame:NSZeroRect]; [sw sizeToFit];
    // NSSwitch centered in 52px row — symmetric formula ✓
    sw.frame=NSMakeRect(bw-sw.frame.size.width-16,(52-sw.frame.size.height)/2,sw.frame.size.width,sw.frame.size.height);
    sw.state=SettingsStore.shared.circadianEnabled?NSControlStateValueOn:NSControlStateValueOff;
    sw.target=self; sw.action=@selector(circadianChanged:);
    [row addSubview:sw]; [p addSubview:row];

    // Day/Night block: design top=162, h=96
    NSView *blocks=[self roundBox:NSMakeRect(lx, PY(y,96), bw, 96)];
    // Row 0 = Daytime at VISUAL TOP of 96px block → NSView ry=48 (from bottom)
    [self circRow:blocks emoji:@"☀" label:@"Daytime" sub:@"Warm Parchment" time:@"7:00 AM" nsry:48 boxH:96];
    // Separator between rows: design top=48 in block → BOTY(96,48,1)=47
    PESep *sep=[[PESep alloc] initWithFrame:NSMakeRect(0, BOTY(96,48,1), bw, 1)];
    [blocks addSubview:sep];
    // Row 1 = Nighttime at VISUAL BOTTOM → NSView ry=0
    [self circRow:blocks emoji:@"◑" label:@"Nighttime" sub:@"Amber Shield" time:@"8:00 PM" nsry:0 boxH:96];
    [p addSubview:blocks];
    return p;
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 3: Display  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildDisplay {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    CGFloat y=PAD_H; CGFloat lx=PAD_V;

    // Title: design top=28, h=22
    NSTextField *ttl=[NSTextField labelWithString:@"Display"];
    ttl.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold]; ttl.textColor=HEX(226,222,209);
    ttl.frame=NSMakeRect(lx, PY(y,22), CONT_W-2*lx, 22); [p addSubview:ttl]; y+=22+4; // y=54
    [self panelSub:p text:@"Choose which monitor the overlay covers." y:&y lx:lx]; // y=98

    // Screen tabs: design top=98, h=30
    NSArray *screens=NSScreen.screens;
    NSInteger n=MIN((NSInteger)screens.count,4);
    NSView *tabBg=[[NSView alloc] initWithFrame:NSMakeRect(lx, PY(y,30), 80, 30)];
    tabBg.wantsLayer=YES; tabBg.layer.cornerRadius=8;
    tabBg.layer.backgroundColor=HEXA(0,0,0,.30).CGColor;
    for (NSInteger i=0;i<n;i++) {
        // Tab button inside tabBg (30px): at y=3, h=24 → symmetric → y=3 ✓
        NSView *tb=[[NSView alloc] initWithFrame:NSMakeRect(3+i*37,3,33,24)];
        tb.wantsLayer=YES; tb.layer.cornerRadius=6;
        tb.layer.backgroundColor=(i==0?HEX(50,40,10):NSColor.clearColor).CGColor;
        NSTextField *num=[NSTextField labelWithString:[NSString stringWithFormat:@"%ld",i+1]];
        num.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        num.textColor=(i==0?HEX(213,210,197):HEX(96,80,64));
        num.alignment=NSTextAlignmentCenter; num.frame=NSMakeRect(0,5,33,14);
        [tb addSubview:num]; [tabBg addSubview:tb];
        if (i>0) tabBg.frame=NSMakeRect(lx, PY(y,30), tabBg.frame.size.width+37, 30);
    }
    [p addSubview:tabBg]; y+=30+16; // y=144

    CGFloat bw=CONT_W-2*lx;
    CGFloat dlistH=(CGFloat)n*48;
    // Display list: design top=144, h=n*48
    NSView *dlist=[self roundBox:NSMakeRect(lx, PY(y,dlistH), bw, dlistH)];
    for (NSInteger i=0;i<n;i++) {
        NSScreen *scr=screens[i];
        NSString *nm=(i==0)?@"Primary Display":[NSString stringWithFormat:@"Display %ld",i+1];
        NSString *res=[NSString stringWithFormat:@"%.0f × %.0f",scr.frame.size.width,scr.frame.size.height];
        // NSView ry for row i (row 0 at TOP): ry = (n-1-i)*48
        CGFloat nsry=(n-1-i)*48;
        [self displayRow:dlist idx:i name:nm res:res isMain:(i==0) nsry:nsry w:bw];
        if (i<n-1) {
            // Separator: design top=(i+1)*48 in dlist → BOTY(n*48,(i+1)*48,1)
            CGFloat sy=BOTY(dlistH,(i+1)*48,1);
            PESep *s2=[[PESep alloc] initWithFrame:NSMakeRect(0,sy,bw,1)];
            [dlist addSubview:s2];
        }
    }
    [p addSubview:dlist]; y+=dlistH+10;

    // Refresh: design top=y, h=14
    NSTextField *refresh=[NSTextField labelWithString:@"↻ Refresh display output"];
    refresh.font=[NSFont systemFontOfSize:11.5]; refresh.textColor=HEX(96,80,64);
    refresh.alignment=NSTextAlignmentRight;
    refresh.frame=NSMakeRect(lx, PY(y,14), CONT_W-2*lx, 14); [p addSubview:refresh];
    return p;
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 4: Exceptions  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildExceptions {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    CGFloat y=PAD_H; CGFloat lx=PAD_V;
    [self panelTitle:p text:@"App Exceptions" y:&y lx:lx]; // y=54
    [self panelSub:p text:@"Vellum will be automatically disabled for these apps." y:&y lx:lx]; // y=98

    CGFloat fieldW=CONT_W-2*lx-8-70;
    // Field + Add button: design top=98, h=34
    // Combo box: type-to-filter list of every installed app (incl. native/system apps).
    _exField=[[NSComboBox alloc] initWithFrame:NSMakeRect(lx, PY(y,26), fieldW, 26)];
    _exField.placeholderString=@"Search apps…";
    _exField.font=[NSFont systemFontOfSize:12.5];
    _exField.completes=YES;            // autocomplete as you type
    _exField.hasVerticalScroller=YES;
    _exField.numberOfVisibleItems=8;
    for (AppInfo *a in _allApps) if (a.name.length) [_exField addItemWithObjectValue:a.name];
    _exField.target=self; _exField.action=@selector(tapAddException);
    [p addSubview:_exField];

    PEBtn *addBtn=[[PEBtn alloc] initWithFrame:NSMakeRect(lx+fieldW+8, PY(y,34), 70, 34)];
    addBtn.title=@"+ Add"; addBtn.primary=YES;
    __weak MenuBarViewController *ws=self;
    addBtn.onTap=^{ [ws tapAddException]; };
    [p addSubview:addBtn]; y+=34+14; // y=146

    CGFloat bw=CONT_W-2*lx;
    // Scroll view: design top=146, h=220
    _exScroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(lx, PY(y,220), bw, 220)];
    _exScroll.hasVerticalScroller=YES; _exScroll.autohidesScrollers=YES;
    _exScroll.drawsBackground=YES; _exScroll.backgroundColor=HEXA(0,0,0,.20);
    _exScroll.wantsLayer=YES; _exScroll.layer.cornerRadius=10;
    _exScroll.layer.borderWidth=1; _exScroll.layer.borderColor=HEXA(255,255,255,.06).CGColor;
    _exList=[[NSView alloc] initWithFrame:NSMakeRect(0,0,bw,220)];
    _exScroll.documentView=_exList;
    [p addSubview:_exScroll];
    [self rebuildExList];
    return p;
}

- (void)rebuildExList {
    for (NSView *v in [_exList.subviews copy]) [v removeFromSuperview];
    NSArray *exc=SettingsStore.shared.excludedAppsInfo;
    CGFloat rh=38, bw=_exList.frame.size.width;
    CGFloat docH=MAX((CGFloat)exc.count*rh,220);
    _exList.frame=NSMakeRect(0,0,bw,docH);

    if (!exc.count) {
        // Empty message: design top=100, h=16 in docH container
        NSTextField *empty=[NSTextField labelWithString:@"No exceptions — overlay appears everywhere"];
        empty.font=[NSFont systemFontOfSize:12]; empty.textColor=HEX(80,64,56);
        empty.alignment=NSTextAlignmentCenter;
        empty.frame=NSMakeRect(0, BOTY(docH,100,16), bw, 16);
        [_exList addSubview:empty];
        return;
    }

    // NSView _exList (y=0 at bottom).
    // Row i is visually at design top = i*rh.
    // NSView y = docH - (i+1)*rh
    for (NSInteger i=0;i<(NSInteger)exc.count;i++) {
        NSDictionary *info=exc[i];
        NSString *name=info[@"name"]?:info[@"bundleId"];
        NSString *bid=info[@"bundleId"]?:@"";
        CGFloat nsry=docH-(i+1)*rh; // NSView y of row bottom

        if (i>0) {
            // Separator sits at the top of this row = nsry+rh
            PESep *s=[[PESep alloc] initWithFrame:NSMakeRect(0, nsry+rh, bw, 1)];
            [_exList addSubview:s];
        }
        // App icon (looked up by bundleId)
        NSImage *ico=nil;
        for (AppInfo *a in _allApps) if ([a.bundleId isEqualToString:bid]) { ico=a.icon; break; }
        CGFloat tx=16;
        if (ico) {
            NSImageView *iv=[NSImageView imageViewWithImage:ico];
            iv.frame=NSMakeRect(16, nsry+(rh-18)/2, 18, 18);
            [_exList addSubview:iv]; tx=42;
        }
        NSTextField *nl=[NSTextField labelWithString:name];
        nl.font=[NSFont systemFontOfSize:13]; nl.textColor=HEX(192,189,176);
        nl.frame=NSMakeRect(tx, nsry+(rh-16)/2, bw-tx-44, 16);
        [_exList addSubview:nl];

        NSButton *xb=[NSButton buttonWithTitle:@"✕" target:self action:@selector(tapRemoveException:)];
        xb.bordered=NO; xb.font=[NSFont systemFontOfSize:12]; xb.contentTintColor=HEX(96,80,64);
        xb.frame=NSMakeRect(bw-36, nsry+(rh-22)/2, 20, 22);
        xb.identifier=bid;
        [_exList addSubview:xb];
    }

    // Scroll to show the top of the document (row 0 at highest NSView y)
    CGFloat visH=_exScroll.contentSize.height;
    CGFloat scrollTo=MAX(0, docH-visH);
    [_exScroll.contentView scrollToPoint:NSMakePoint(0, scrollTo)];
    [_exScroll reflectScrolledClipView:_exScroll.contentView];
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Panel 5: License  (NSView, PY() for all y)
// ─────────────────────────────────────────────────────────────────────────
- (NSView *)buildLicense {
    NSView *p=[[NSView alloc] initWithFrame:NSMakeRect(0,0,CONT_W,WIN_H)];
    CGFloat y=PAD_H; CGFloat lx=PAD_V;
    [self panelTitle:p text:@"License" y:&y lx:lx]; // y=54
    [self panelSub:p text:@"Manage your Vellum license." y:&y lx:lx]; // y=98

    CGFloat bw=CONT_W-2*lx;
    // Status box: design top=98, h=60
    NSView *statBox=[self roundBox:NSMakeRect(lx, PY(y,60), bw, 60)]; y+=60+14; // y=172
    // NSView statBox (h=60):
    // "Status" label: design top=12, h=13 → BOTY(60,12,13)=35
    NSTextField *sl=[NSTextField labelWithString:@"Status"];
    sl.font=[NSFont systemFontOfSize:9.5 weight:NSFontWeightBold]; sl.textColor=HEX(80,64,56);
    sl.frame=NSMakeRect(16, BOTY(60,12,13), 80, 13); [statBox addSubview:sl];
    // Gold dot: design top=32, h=8 → BOTY(60,32,8)=20
    NSView *dot=[[NSView alloc] initWithFrame:NSMakeRect(16, BOTY(60,32,8), 8, 8)];
    dot.wantsLayer=YES; dot.layer.cornerRadius=4; dot.layer.backgroundColor=HEX(200,168,64).CGColor;
    [statBox addSubview:dot];
    // Active label: design top=29, h=18 → BOTY(60,29,18)=13
    NSTextField *active=[NSTextField labelWithString:@"Active · Personal License"];
    active.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; active.textColor=HEX(212,188,96);
    active.frame=NSMakeRect(30, BOTY(60,29,18), bw-50, 18); [statBox addSubview:active];
    [p addSubview:statBox];

    // Key field: design top=172, h=34
    NSTextField *kf=[[NSTextField alloc] initWithFrame:NSMakeRect(lx, PY(y,34), bw, 34)];
    kf.placeholderString=@"XXXX-XXXX-XXXX-XXXX";
    kf.font=[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    kf.backgroundColor=HEXA(0,0,0,.30); kf.textColor=HEX(192,189,176);
    kf.bezelStyle=NSTextFieldRoundedBezel; kf.bordered=YES;
    [p addSubview:kf]; y+=34+10; // y=216

    // Activate button: design top=216, h=38
    PEBtn *actBtn=[[PEBtn alloc] initWithFrame:NSMakeRect(lx, PY(y,38), bw, 38)];
    actBtn.title=@"Activate License"; actBtn.primary=YES;
    [p addSubview:actBtn];
    return p;
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Layout helpers
// ─────────────────────────────────────────────────────────────────────────

// panelTitle: y tracks design y-from-top; PY() converts for NSView frame.
- (void)panelTitle:(NSView*)p text:(NSString*)t y:(CGFloat*)y lx:(CGFloat)lx {
    NSTextField *tf=[NSTextField labelWithString:t];
    tf.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold]; tf.textColor=HEX(226,222,209);
    tf.frame=NSMakeRect(lx, PY(*y,22), CONT_W-2*lx, 22); [p addSubview:tf]; *y+=22+4;
}
- (void)panelSub:(NSView*)p text:(NSString*)t y:(CGFloat*)y lx:(CGFloat)lx {
    NSTextField *tf=[NSTextField labelWithString:t];
    tf.font=[NSFont systemFontOfSize:12]; tf.textColor=HEX(112,96,80);
    tf.lineBreakMode=NSLineBreakByWordWrapping;
    tf.frame=NSMakeRect(lx, PY(*y,28), CONT_W-2*lx, 28); [p addSubview:tf]; *y+=28+16;
}
- (NSView*)roundBox:(NSRect)fr {
    NSView *v=[[NSView alloc] initWithFrame:fr];
    v.wantsLayer=YES; v.layer.cornerRadius=10;
    v.layer.backgroundColor=HEXA(0,0,0,.20).CGColor;
    v.layer.borderWidth=1; v.layer.borderColor=HEXA(255,255,255,.06).CGColor;
    return v;
}
// rowTitle: places title+sub in a roundBox of height boxH (NSView, y=0 at bottom).
// Design positions: title at top=15 h=18, sub at top=33 h=14.
- (void)rowTitle:(NSView*)box t:(NSString*)t s:(NSString*)s greenSub:(BOOL)green boxH:(CGFloat)boxH {
    NSTextField *tl=[NSTextField labelWithString:t];
    tl.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; tl.textColor=HEX(208,203,192);
    tl.frame=NSMakeRect(16, BOTY(boxH,15,18), box.frame.size.width-80, 18); [box addSubview:tl];
    NSTextField *sl=[NSTextField labelWithString:s];
    sl.font=[NSFont systemFontOfSize:11]; sl.textColor=(green?HEX(97,128,86):HEX(96,80,64));
    sl.frame=NSMakeRect(16, BOTY(boxH,33,14), box.frame.size.width-80, 14); [box addSubview:sl];
}
// circRow: one 48px row in a roundBox.  nsry = NSView y from box bottom for this row.
// Main label at design top+10, sub at design top+28 within the row → NSView: ry+22, ry+6
- (void)circRow:(NSView*)box emoji:(NSString*)em label:(NSString*)lb sub:(NSString*)sb time:(NSString*)tm nsry:(CGFloat)nsry boxH:(CGFloat)boxH {
    CGFloat rh=48;
    // Icon circle: vertically centered in row
    NSView *ico=[[NSView alloc] initWithFrame:NSMakeRect(16, nsry+(rh-28)/2, 28, 28)];
    ico.wantsLayer=YES; ico.layer.cornerRadius=14;
    ico.layer.backgroundColor=HEXA(255,220,80,.10).CGColor;
    // Emoji inside 28px icon: y=6 from design top → BOTY(28,6,16)=6 (symmetric) ✓
    NSTextField *et=[NSTextField labelWithString:em];
    et.font=[NSFont systemFontOfSize:14]; et.frame=NSMakeRect(7,6,16,16);
    [ico addSubview:et]; [box addSubview:ico];
    // Main label: design "10px from row top", h=16 → NSView y = nsry+(rh-10-16) = nsry+22
    NSTextField *lt=[NSTextField labelWithString:lb];
    lt.font=[NSFont systemFontOfSize:12.5 weight:NSFontWeightMedium]; lt.textColor=HEX(208,203,192);
    lt.frame=NSMakeRect(52, nsry+22, 160, 16); [box addSubview:lt];
    // Sub label: design "28px from row top", h=14 → NSView y = nsry+(rh-28-14) = nsry+6
    NSTextField *st2=[NSTextField labelWithString:sb];
    st2.font=[NSFont systemFontOfSize:10.5]; st2.textColor=HEX(96,80,64);
    st2.frame=NSMakeRect(52, nsry+6, 160, 14); [box addSubview:st2];
    // Time: vertically centered in row
    NSTextField *tt=[NSTextField labelWithString:tm];
    tt.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]; tt.textColor=HEX(122,106,88);
    tt.alignment=NSTextAlignmentRight;
    tt.frame=NSMakeRect(box.frame.size.width-80, nsry+(rh-16)/2, 68, 16); [box addSubview:tt];
}
// displayRow: one 48px display row in dlist.  nsry = NSView y from dlist bottom.
- (void)displayRow:(NSView*)box idx:(NSInteger)i name:(NSString*)nm res:(NSString*)rs isMain:(BOOL)main nsry:(CGFloat)nsry w:(CGFloat)w {
    // Badge circle: vertically centered
    NSView *badge=[[NSView alloc] initWithFrame:NSMakeRect(16, nsry+(48-22)/2, 22, 22)];
    badge.wantsLayer=YES; badge.layer.cornerRadius=11;
    badge.layer.backgroundColor=(main?HEX(50,40,10):HEXA(255,255,255,.07)).CGColor;
    NSTextField *bn=[NSTextField labelWithString:[NSString stringWithFormat:@"%ld",i+1]];
    bn.font=[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];
    bn.textColor=(main?HEX(212,188,96):HEX(97,128,86)); bn.alignment=NSTextAlignmentCenter;
    // Label inside 22px badge: y=4 from design top → BOTY(22,4,14)=4 (symmetric) ✓
    bn.frame=NSMakeRect(0,4,22,14); [badge addSubview:bn]; [box addSubview:badge];
    // Name: design "10px from row top", h=16 → NSView y = nsry+22
    NSTextField *nt=[NSTextField labelWithString:nm];
    nt.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; nt.textColor=HEX(208,203,192);
    nt.frame=NSMakeRect(46, nsry+22, 200, 16); [box addSubview:nt];
    // Res: design "28px from row top", h=14 → NSView y = nsry+6
    NSTextField *rt=[NSTextField labelWithString:rs];
    rt.font=[NSFont systemFontOfSize:11]; rt.textColor=HEX(96,80,64);
    rt.frame=NSMakeRect(46, nsry+6, 200, 14); [box addSubview:rt];
    if (main) {
        NSTextField *chk=[NSTextField labelWithString:@"✓"];
        chk.font=[NSFont systemFontOfSize:14]; chk.textColor=HEX(200,168,64);
        chk.alignment=NSTextAlignmentRight;
        chk.frame=NSMakeRect(w-36, nsry+(48-18)/2, 26, 18); [box addSubview:chk];
    }
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Texture generation (80×80 thumbnails)
// ─────────────────────────────────────────────────────────────────────────
- (void)generateTextures {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        NSMutableArray *thumbs=[NSMutableArray array];
        for (int i=0;i<PMTextureCount;i++) {
            NSImage *full=[PaperTextureGenerator textureForType:(PMTextureType)i];
            NSImage *thumb=nil;
            if (full) {
                thumb=[[NSImage alloc] initWithSize:NSMakeSize(80,80)];
                [thumb lockFocus];
                [full drawInRect:NSMakeRect(0,0,80,80) fromRect:NSZeroRect
                       operation:NSCompositingOperationSourceOver fraction:1];
                [thumb unlockFocus];
            }
            [thumbs addObject:thumb?:(NSImage*)NSNull.null];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.thumbImgs=thumbs;
            for (PETexCard *card in self.texCards) {
                NSInteger idx=card.texType;
                if (idx<(NSInteger)thumbs.count && thumbs[idx]!=(id)NSNull.null)
                    card.thumbImg=(NSImage*)thumbs[idx];
            }
        });
    });
}

// ─────────────────────────────────────────────────────────────────────────
#pragma mark – Actions
// ─────────────────────────────────────────────────────────────────────────
- (void)tapOn {
    SettingsStore *st=SettingsStore.shared;
    st.isEnabled=!st.isEnabled;
    if (st.isEnabled) { st.isSnoozed=NO; [OverlayManager.shared enable]; }
    else [OverlayManager.shared disable];
    [self updateProtectionUI];
}

- (void)tapSnooze {
    SettingsStore *st=SettingsStore.shared;
    if (!st.isEnabled) return;
    [OverlayManager.shared setSnooze:!st.isSnoozed];
    [self updateProtectionUI];
}

- (void)sliderChanged:(NSSlider*)sl {
    SettingsStore *st=SettingsStore.shared;
    st.intensity=sl.doubleValue;
    NSString *pct=[NSString stringWithFormat:@"%d%%",(int)(sl.doubleValue*100)];
    _intensityPct.stringValue=pct;
    _intensityTxt.stringValue=[NSString stringWithFormat:@"Intensity %@",pct];
    if (st.isEnabled) [OverlayManager.shared update];
}

- (void)circadianChanged:(NSSwitch*)sw {
    SettingsStore.shared.circadianEnabled=(sw.state==NSControlStateValueOn);
}

- (void)pickTexture:(PMTextureType)type {
    SettingsStore *st=SettingsStore.shared;
    st.selectedTexture=type;
    st.intensity=PMTextureDefaultOpacity(type);
    _intensitySlider.doubleValue=st.intensity;
    NSString *pct=[NSString stringWithFormat:@"%d%%",(int)(st.intensity*100)];
    _intensityPct.stringValue=pct;
    _intensityTxt.stringValue=[NSString stringWithFormat:@"Intensity %@",pct];
    _activeTexTxt.stringValue=PMTextureName(type);
    for (PETexCard *c in _texCards) c.selected=(c.texType==type);
    if (st.isEnabled) [OverlayManager.shared update];
}

- (void)tapAddException {
    NSString *text=[_exField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!text.length) return;
    NSString *q=text.lowercaseString;
    // Match precedence: exact name → prefix → contains. Reliable name→bundleId mapping.
    AppInfo *exact=nil, *prefix=nil, *contains=nil;
    for (AppInfo *app in _allApps) {
        NSString *n=app.name.lowercaseString;
        if ([n isEqualToString:q]) { exact=app; break; }
        if (!prefix && [n hasPrefix:q]) prefix=app;
        else if (!contains && [n containsString:q]) contains=app;
    }
    AppInfo *m=exact?:prefix?:contains;
    NSString *bid=m?m.bundleId:text, *nm=m?m.name:text;
    if ([SettingsStore.shared isAppExcluded:bid]) { _exField.stringValue=@""; return; } // already excluded
    [SettingsStore.shared addExclusionByName:nm bundleId:bid];
    _exField.stringValue=@"";
    [self rebuildExList];
    [OverlayManager.shared updateVisibilityForFocusedApp];
}

- (void)tapRemoveException:(NSButton*)btn {
    [SettingsStore.shared removeExclusionByBundleId:btn.identifier];
    [self rebuildExList];
    [OverlayManager.shared updateVisibilityForFocusedApp];
}

- (void)updateProtectionUI {
    SettingsStore *st=SettingsStore.shared;
    BOOL on=st.isEnabled, snz=st.isSnoozed;
    _onBtn.title=on?@"◉  On":@"○  Off"; _onBtn.primary=on; [_onBtn setNeedsDisplay:YES];
    _snoozeBtn.title=snz?@"⏰ Snoozed":@"⏸ Snooze"; [_snoozeBtn setNeedsDisplay:YES];
    if (snz)      _statusTxt.stringValue=@"Snoozed · resumes at 8:00 AM";
    else if (on)  _statusTxt.stringValue=@"Protecting your screen";
    else          _statusTxt.stringValue=@"Protection is off";
    _statusTxt.textColor=(on&&!snz)?HEX(200,168,64):(snz?HEX(200,168,64):HEX(100,126,84));
    _activeTexTxt.stringValue=PMTextureName(st.selectedTexture);
    NSString *pct=[NSString stringWithFormat:@"%d%%",(int)(st.intensity*100)];
    _intensityTxt.stringValue=[NSString stringWithFormat:@"Intensity %@",pct];
    _intensityPct.stringValue=pct;
}

@end
