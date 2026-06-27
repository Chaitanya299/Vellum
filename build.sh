#!/bin/bash
set -e

APP="Vellum.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
BINARY="$MACOS/Vellum"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macos12.0"
else
    TARGET="x86_64-apple-macos12.0"
fi

echo "→ Building Vellum ($ARCH, Objective-C)..."

# Always remove any old running instance and stale copies first
pkill -9 Vellum 2>/dev/null || true
pkill -9 PaperEye 2>/dev/null || true
pkill -9 Paperman 2>/dev/null || true
rm -rf "$APP"
rm -rf /Applications/Vellum.app
rm -rf /Applications/PaperEye.app
rm -rf /Applications/Paperman.app
mkdir -p "$MACOS" "$RESOURCES"

clang \
    -fobjc-arc \
    -target "$TARGET" \
    -framework Cocoa \
    -framework CoreGraphics \
    -framework CoreText \
    -framework QuartzCore \
    -framework CoreImage \
    -O2 \
    SourcesObjC/main.m \
    SourcesObjC/AppDelegate.m \
    SourcesObjC/SettingsStore.m \
    SourcesObjC/AppManager.m \
    SourcesObjC/PaperTextureGenerator.m \
    SourcesObjC/TextureOverlayView.m \
    SourcesObjC/OverlayManager.m \
    SourcesObjC/VellumIcon.m \
    SourcesObjC/MenuBarViewController.m \
    SourcesObjC/MenuBarPopover.m \
    -o "$BINARY"

# ── App icon: render VellumIcon → .iconset → AppIcon.icns ──────────────────
echo "→ Generating Vellum app icon…"
clang -fobjc-arc -target "$TARGET" -framework Cocoa -framework CoreGraphics -O2 \
    SourcesObjC/VellumIcon.m SourcesObjC/geniconset.m -o /tmp/pe_geniconset
rm -rf /tmp/AppIcon.iconset
/tmp/pe_geniconset /tmp/AppIcon.iconset >/dev/null
iconutil -c icns /tmp/AppIcon.iconset -o "$RESOURCES/AppIcon.icns"

# ── Bundle the Cormorant Garamond wordmark font ───────────────────────────
if [ -d Resources/fonts ]; then
    mkdir -p "$RESOURCES/fonts"
    cp Resources/fonts/*.ttf "$RESOURCES/fonts/" 2>/dev/null || true
fi

cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS runs it without quarantine complaints
codesign --force --deep --sign - "$APP" 2>/dev/null \
    && echo "→ Code signed (ad-hoc)" \
    || echo "⚠  codesign not available – run manually if needed"

# Install to /Applications so it's findable in Finder / Launchpad / Spotlight
rm -rf /Applications/Vellum.app
cp -R "$APP" /Applications/Vellum.app
xattr -dr com.apple.quarantine /Applications/Vellum.app 2>/dev/null || true

echo ""
echo "✓ Build complete → $APP  (installed to /Applications/Vellum.app)"
echo ""
echo "  Vellum is a menu-bar app — look for the gold orb in the top-right menu bar."
echo "  Launch:  open -a Vellum"
