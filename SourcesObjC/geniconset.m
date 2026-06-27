#import <AppKit/AppKit.h>
#import "VellumIcon.h"

// Writes a macOS .iconset directory (PNGs at all required sizes) from VellumIcon.
// Usage: geniconset <output.iconset dir>
static void writePNG(NSImage *img, NSString *path) {
    CGImageRef cg = [img CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:path atomically:YES];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { fprintf(stderr, "usage: geniconset <dir.iconset>\n"); return 1; }
        NSString *dir = [NSString stringWithUTF8String:argv[1]];
        [NSFileManager.defaultManager createDirectoryAtPath:dir
            withIntermediateDirectories:YES attributes:nil error:nil];
        // (size, @2x?) → filename
        struct { int px; const char *name; } items[] = {
            {16,  "icon_16x16.png"},     {32,  "icon_16x16@2x.png"},
            {32,  "icon_32x32.png"},     {64,  "icon_32x32@2x.png"},
            {128, "icon_128x128.png"},   {256, "icon_128x128@2x.png"},
            {256, "icon_256x256.png"},   {512, "icon_256x256@2x.png"},
            {512, "icon_512x512.png"},   {1024,"icon_512x512@2x.png"},
        };
        for (int i=0; i<10; i++) {
            NSImage *img = [VellumIcon iconWithSize:items[i].px];
            NSString *p = [dir stringByAppendingPathComponent:
                           [NSString stringWithUTF8String:items[i].name]];
            writePNG(img, p);
        }
        printf("wrote 10 png sizes to %s\n", argv[1]);
        return 0;
    }
}
