#import "AppManager.h"
#import <AppKit/AppKit.h>

@implementation AppInfo
@end

@implementation AppManager

+ (NSArray<AppInfo*> *)installedApplications {
    NSMutableArray<AppInfo*> *apps = [NSMutableArray array];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *appDirs = @[@"/Applications",
                         @"/Applications/Utilities",
                         @"/System/Applications",            // native apps: Safari, Mail, Notes, …
                         @"/System/Applications/Utilities",  // Terminal, Activity Monitor, …
                         [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"]];
    NSMutableSet *seen = [NSMutableSet set];

    for (NSString *dir in appDirs) {
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *item in contents) {
            if (![item.pathExtension isEqual:@"app"]) continue;
            NSString *appPath = [dir stringByAppendingPathComponent:item];
            NSBundle *bundle = [NSBundle bundleWithPath:appPath];
            if (!bundle || !bundle.bundleIdentifier) continue;
            if ([seen containsObject:bundle.bundleIdentifier]) continue;
            [seen addObject:bundle.bundleIdentifier];

            AppInfo *info = [[AppInfo alloc] init];
            info.bundleId = bundle.bundleIdentifier;
            info.name = bundle.infoDictionary[@"CFBundleDisplayName"] ?: bundle.bundlePath.lastPathComponent.stringByDeletingPathExtension;
            NSImage *ico = [NSWorkspace.sharedWorkspace iconForFile:appPath];
            if (ico) { [ico setSize:NSMakeSize(16, 16)]; }
            info.icon = ico;
            [apps addObject:info];
        }
    }

    [apps sortUsingComparator:^(AppInfo *a, AppInfo *b) {
        return [a.name caseInsensitiveCompare:b.name];
    }];
    return apps;
}

@end
