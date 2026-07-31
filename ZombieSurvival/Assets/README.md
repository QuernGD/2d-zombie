# Assets

This folder is added to the Xcode project as a **folder reference** (shows
up blue, not yellow, in the navigator), so anything placed inside it is
automatically copied into the app bundle, preserving its subfolder
structure — no project file edits needed.

Because a folder reference preserves that on-disk structure, a bare
`UIImage(named:)` lookup (which only searches the bundle root and compiled
asset catalogs) can't find anything nested in here. `AssetProvider`'s
`resolveImage` works around this by trying an explicit bundle path
(`Bundle.main.url(forResource:withExtension:subdirectory:)`) first and only
falling back to `UIImage(named:)` for `Assets.xcassets` entries.

## Layout (as of Phase 4)

```
Assets/
  Characters/
    Player/          idle, run, hit, knocked, death        (32x32 frames)
    Zombie1..4/       idle, run, hit, knocked, death1[, death2]
  Weapons/            pistol_shoot, revolver_shoot, rifle_shoot,
                      rocketlauncher_shoot, shotgun_shoot, sniper_shoot
  Items/              coin, medkit, ammo                    (16x16 frames)
  Tiles/              wasteland, interior                   (32x32 tilesets)
  UI/                 panel1, panel2, health_bar_fillers
  ZOMBIEPACK_LICENSE.txt
```

Every file above (except the tilesets and the two panel/health-bar sheets)
is a horizontal-strip spritesheet: fixed-size square frames side by side,
no padding, so frame count = sheet width ÷ frame size. There are no
individual numbered frame files in this project anymore — Phase 2's
`skeleton-idle_0...16`-style loose frames were removed once the real
character art (delivered as single sheets) replaced them.

## Two loading paths

`AssetProvider.swift` (in `Support/`) supports both:

- **Single static image**, looked up by `EntityVisualKind` case name
  (`player`, `walker`, `bullet`) via `makeNode(for:radius:fillColor:)` —
  falls back to a placeholder colored circle if no image resolves.
- **Spritesheet animation**, via `SpriteSheetFrames` +
  `loadSpriteSheetTextures` / `makeAnimatedNode(sheet:size:fallbackColor:)`
  — this is what every file listed above uses. Give it the bare sheet name
  (no extension), frame size, frame count, and subdirectory (e.g.
  `"Assets/Characters/Zombie1"`), and it slices the sheet into textures.
- Tile-based art (the two tilesets) instead goes through
  `AssetProvider.loadTileTexture(sheetName:subdirectory:tileSize:column:row:)`,
  a column/row grid extractor used by `Systems/TileMapBuilder.swift` — see
  the root README's Phase 4 section for the tile-index caveats.

The legacy numbered-frame path (`AnimationFrameSequence` /
`loadTextures` / `makeAnimatedNode(for:frames:radius:fillColor:)`) still
exists for backward compatibility but has no current callers now that
Walker/Player have moved to spritesheets.
