#import <AppKit/AppKit.h>
#import "TextureType.h"

@interface PaperTextureGenerator : NSObject
// Returns a 512×512 tiled texture image for the given type.
// Texture is deterministic (same seed → same pixels).
+ (NSImage *)textureForType:(PMTextureType)type;
@end
