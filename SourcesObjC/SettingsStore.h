#import <Foundation/Foundation.h>
#import "TextureType.h"

@interface SettingsStore : NSObject
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isSnoozed;           // transient, not persisted
@property (nonatomic, assign) double intensity;
@property (nonatomic, assign) PMTextureType selectedTexture;
@property (nonatomic, assign) PMTextureType dayTexture;
@property (nonatomic, assign) PMTextureType nightTexture;
@property (nonatomic, assign) BOOL circadianEnabled;
@property (nonatomic, strong) NSMutableSet<NSString*> *excludedAppBundleIds;
+ (instancetype)shared;
- (BOOL)isAppExcluded:(NSString *)bundleId;
- (void)toggleExclusionForApp:(NSString *)bundleId;
- (void)addExclusionByName:(NSString *)name bundleId:(NSString *)bundleId;
- (void)removeExclusionByBundleId:(NSString *)bundleId;
// Returns array of {name, bundleId} dicts for excluded apps
- (NSArray<NSDictionary*> *)excludedAppsInfo;
@end
