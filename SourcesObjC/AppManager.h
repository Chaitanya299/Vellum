#import <Foundation/Foundation.h>

@interface AppInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *bundleId;
@property (nonatomic, strong) NSImage *icon;
@end

@interface AppManager : NSObject
+ (NSArray<AppInfo*> *)installedApplications;
@end
