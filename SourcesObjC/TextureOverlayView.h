#import <AppKit/AppKit.h>
#import "TextureType.h"

@interface TextureOverlayView : NSView
@property (nonatomic, assign) double intensity;
@property (nonatomic, assign) PMTextureType textureType;
- (instancetype)initWithFrame:(NSRect)frame
                    intensity:(double)intensity
                      texture:(PMTextureType)texture;
@end
