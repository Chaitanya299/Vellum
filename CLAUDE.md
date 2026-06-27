# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Vellum** — a macOS menu-bar app that draws a procedural paper-texture overlay across every
screen, tinting the display to look like paper and cutting blue light (an eye-strain / night
filter). It has been renamed twice (PaperEye → Paperman → Vellum); the bundle id is still
`com.papereye.local`. `Vellum.app` is the live (and only) bundle.

## Source tree

**`SourcesObjC/` (Objective-C) is the whole app.** Built by `./build.sh` into `Vellum.app`. Full
feature set: 12 textures, circadian day/night schedule, menu-bar popover, per-app exclusions, app
icon generation. ~2800 lines. (A legacy Swift prototype under `Sources/` + `Package.swift` was
removed — there is no longer a `swift build` path.)

## Build & run

```bash
./build.sh          # clang-compiles SourcesObjC, makes the icon, bundles fonts,
                    # ad-hoc signs, and installs to /Applications/Vellum.app
open -a Vellum      # launch (look for the gold orb in the menu bar)
```

`build.sh` kills any running Vellum/PaperEye/Paperman first and is the only supported build path
for the real app. There is no test suite, linter, or CI — verification is manual (run it, check
the overlay renders, toggle settings). When you add a `.m`/`.h` file, add it to the `clang` source
list in `build.sh` or it won't compile in.

## Architecture (ObjC tree)

Singletons + manual AppKit, no Storyboards, no Auto Layout (views use explicit frames /
springs-and-struts — comments deliberately avoid the constraint engine to dodge layout
exceptions).

- **`AppDelegate`** — owns the menu-bar `NSStatusItem`, the dark "Vellum" controls window, and the
  glassy menu-bar popover. Left-click status item → popover; right-click → quit menu.
- **`OverlayManager` (singleton)** — the core. Creates one borderless `PMOverlayWindow` per
  `NSScreen`, rebuilds on screen/Space changes, and shows/hides the overlay based on the frontmost
  app. `enable`/`disable`/`update`/`setSnooze:`.
- **`TextureOverlayView`** — Core Graphics `drawRect:`: a base-colour tint pass + a tiled paper-grain
  pass (soft-light). Caches the generated texture image.
- **`PaperTextureGenerator`** — procedurally renders each texture to an `NSImage`.
- **`TextureType.h`** — the `PMTextureType` enum (9 daytime + 3 nighttime textures) plus inline
  metadata: display name, base RGB, default opacity, blue-light/night/dark flags. Adding a texture
  means extending every table here.
- **`SettingsStore` (singleton)** — all persisted state via `NSUserDefaults` (`isEnabled`,
  `intensity`, `texture`, `dayTexture`, `nightTexture`, `circadianEnabled`, `excludedAppsInfo`).
  `isSnoozed` is transient. App exclusions are stored as `{name, bundleId}` dicts.
- **`MenuBarViewController`** (~1000 lines) — the entire settings UI, hand-built. The big file.
- **`AppManager`** — enumerates installed apps (for the per-app exclusion picker).
- **`VellumIcon` / `geniconset.m`** — render the orb logo; `geniconset` is a build-time tool that
  emits the `.iconset` for `iconutil`.

### Window-level tricks worth knowing before you touch overlay/window code

These are load-bearing and non-obvious (the comments explain why):

- The app uses `NSApplicationActivationPolicyAccessory`. Combined with
  `NSWindowCollectionBehaviorCanJoinAllSpaces`, the overlay floats over *other* apps' native
  fullscreen Spaces. A Regular-policy app would hide the overlay in fullscreen.
- Overlay windows sit at `NSScreenSaverWindowLevel` (above fullscreen content), are
  `ignoresMouseEvents`, and must NOT use `FullScreenAuxiliary` (that ties them to our own fullscreen
  window and suppresses them elsewhere). Controls window is `+1`, popover `+2`.
- Per-app show/hide listens on **`NSWorkspace.sharedWorkspace.notificationCenter`**, not the default
  center — workspace notifications never reach the default center.

## Notes

- Comments reference external design specs (`*.dc.html`, "Brief §N"). Those files are not in the
  repo; treat them as historical design intent, not something to read.
- Bundled font: Cormorant Garamond (`Resources/fonts/`), loaded per-process at launch.

---

## Session Start Protocol ⚡

**MANDATORY** at start of each session:

```bash
# Load essential docs (~800 tokens - 2 min read)
✓ .claude/COMMON_MISTAKES.md      # ⚠️ CRITICAL - Read FIRST
✓ .claude/QUICK_START.md          # Essential commands
✓ .claude/ARCHITECTURE_MAP.md     # File locations
```

**At task completion:**
- Create completion doc in `.claude/completions/YYYY-MM-DD-task-name.md`
- Move session file to `.claude/sessions/archive/` (if created)

**⚠️ NEVER auto-load:**
- Files in `.claude/completions/` (0 token cost)
- Files in `.claude/sessions/` (0 token cost)
- Files in `docs/archive/` (0 token cost)

---

**Last Updated**: 2026-06-27
**Optimized with**: [Claude Token Optimizer](https://github.com/nadimtuhin/claude-token-optimizer)
