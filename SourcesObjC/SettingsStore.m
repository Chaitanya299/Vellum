#import "SettingsStore.h"

@implementation SettingsStore {
    NSMutableArray<NSDictionary*> *_excludedAppsInfo; // {name, bundleId}
}

+ (instancetype)shared {
    static SettingsStore *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    _isEnabled        = [d boolForKey:@"isEnabled"];
    _isSnoozed        = NO;
    double saved      = [d doubleForKey:@"intensity"];
    _intensity        = saved == 0.0 ? 0.40 : saved;
    NSInteger tex     = [d integerForKey:@"texture"];
    _selectedTexture  = (tex >= 0 && tex < PMTextureCount) ? (PMTextureType)tex : PMTextureWarmParchment;
    NSInteger dayTex  = [d integerForKey:@"dayTexture"];
    _dayTexture       = (dayTex >= 0 && dayTex < PMTextureCount) ? (PMTextureType)dayTex : PMTextureWarmParchment;
    NSInteger nightTex= [d integerForKey:@"nightTexture"];
    _nightTexture     = (nightTex >= 0 && nightTex < PMTextureCount) ? (PMTextureType)nightTex : PMTextureAmberShield;
    _circadianEnabled = [d boolForKey:@"circadianEnabled"];
    // excluded apps stored as array of {name, bundleId} dicts
    NSArray *saved2   = [d arrayForKey:@"excludedAppsInfo"];
    _excludedAppsInfo = [NSMutableArray arrayWithArray:(saved2 ?: @[])];
    _excludedAppBundleIds = [NSMutableSet set];
    for (NSDictionary *info in _excludedAppsInfo) {
        NSString *bid = info[@"bundleId"];
        if (bid.length) [_excludedAppBundleIds addObject:bid];
    }
    return self;
}

- (void)_saveExcluded {
    [NSUserDefaults.standardUserDefaults setObject:_excludedAppsInfo forKey:@"excludedAppsInfo"];
    [_excludedAppBundleIds removeAllObjects];
    for (NSDictionary *info in _excludedAppsInfo) {
        NSString *bid = info[@"bundleId"];
        if (bid.length) [_excludedAppBundleIds addObject:bid];
    }
}

- (void)setIsEnabled:(BOOL)v {
    _isEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:@"isEnabled"];
}
- (void)setIntensity:(double)v {
    _intensity = v;
    [NSUserDefaults.standardUserDefaults setDouble:v forKey:@"intensity"];
}
- (void)setSelectedTexture:(PMTextureType)v {
    _selectedTexture = v;
    [NSUserDefaults.standardUserDefaults setInteger:v forKey:@"texture"];
}
- (void)setDayTexture:(PMTextureType)v {
    _dayTexture = v;
    [NSUserDefaults.standardUserDefaults setInteger:v forKey:@"dayTexture"];
}
- (void)setNightTexture:(PMTextureType)v {
    _nightTexture = v;
    [NSUserDefaults.standardUserDefaults setInteger:v forKey:@"nightTexture"];
}
- (void)setCircadianEnabled:(BOOL)v {
    _circadianEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:@"circadianEnabled"];
}

- (BOOL)isAppExcluded:(NSString *)bundleId {
    return [_excludedAppBundleIds containsObject:bundleId];
}

- (void)toggleExclusionForApp:(NSString *)bundleId {
    if ([self isAppExcluded:bundleId]) {
        [self removeExclusionByBundleId:bundleId];
    } else {
        [self addExclusionByName:bundleId bundleId:bundleId];
    }
}

- (void)addExclusionByName:(NSString *)name bundleId:(NSString *)bundleId {
    if (!bundleId.length || [self isAppExcluded:bundleId]) return;
    [_excludedAppsInfo addObject:@{@"name": name ?: bundleId, @"bundleId": bundleId}];
    [self _saveExcluded];
}

- (void)removeExclusionByBundleId:(NSString *)bundleId {
    NSMutableArray *toRemove = [NSMutableArray array];
    for (NSDictionary *info in _excludedAppsInfo) {
        if ([info[@"bundleId"] isEqualToString:bundleId]) [toRemove addObject:info];
    }
    [_excludedAppsInfo removeObjectsInArray:toRemove];
    [self _saveExcluded];
}

- (NSArray<NSDictionary*> *)excludedAppsInfo {
    return [_excludedAppsInfo copy];
}

@end
