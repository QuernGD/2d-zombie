# Assets

Drop real sprite images in here (or directly into `Assets.xcassets`).

This folder is added to the Xcode project as a **folder reference** (shows
up blue, not yellow, in the navigator), so anything you place inside it is
automatically copied into the app bundle — no project file edits needed.

## Naming convention

`AssetProvider.swift` (in `Support/`) looks up textures by name. To replace
a placeholder shape with a real sprite, add an image whose name matches the
`EntityVisualKind` case, either here or in `Assets.xcassets`:

| Entity | Expected image name |
|---|---|
| Player | `player` |
| Walker (zombie) | `walker` |
| Bullet | `bullet` |
| Coin | `coin` |

As soon as an image with that name resolves via `UIImage(named:)`,
`AssetProvider` swaps the placeholder shape for the real sprite — no other
code changes required. Add new cases to `EntityVisualKind` for future
entity types (new enemy types, weapons, etc.) following the same pattern.

## Animated sprites

For numbered animation frame sequences (idle/move/attack cycles, not just
a single static image), use `AssetProvider.loadTextures` /
`makeAnimatedNode(for:frames:radius:)` with an `AnimationFrameSequence`
instead of the single-image path above. See
`Assets/Enemies/Zombie/README.md` for a concrete example (the Walker's
idle/move/attack frames).
