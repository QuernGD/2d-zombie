# Zombie (Walker) animation frames — expected here

`Walker` (in `Entities/Walker.swift`) looks for three numbered frame
sequences at this path via `AssetProvider.loadTextures`:

| Sequence | Base name | Frame count | Files expected |
|---|---|---|---|
| Idle | `skeleton-idle` | 17 | `skeleton-idle_0.png` ... `skeleton-idle_16.png` |
| Move | `skeleton-move` | 17 | `skeleton-move_0.png` ... `skeleton-move_16.png` |
| Attack | `skeleton-attack` | 9 | `skeleton-attack_0.png` ... `skeleton-attack_8.png` |

Drop the PNGs directly in this folder (it's a folder reference in the
Xcode project, so anything placed here is picked up automatically — no
project file edits needed) **or** add them to `Assets.xcassets` under the
same names; `AssetProvider` checks both.

Until every frame in a sequence is present, `Walker` falls back to the
Phase 1 placeholder circle with no animation — it checks all frames in a
sequence up front and only switches over once the full set resolves, so a
partial drop never animates through blank/missing frames.

There is intentionally no death animation in this set — on death, Walker
plays a 0.25s scale-down + fade-out (code, not sprite frames) and removes
itself.
