# Zombie (Walker) animation frames

`Walker` (in `Entities/Walker.swift`) loads three numbered frame sequences
from this folder via `AssetProvider.loadTextures`, all present and checked
in:

| Sequence | Base name | Frame count | Files |
|---|---|---|---|
| Idle | `skeleton-idle` | 17 | `skeleton-idle_0.png` ... `skeleton-idle_16.png` |
| Move | `skeleton-move` | 17 | `skeleton-move_0.png` ... `skeleton-move_16.png` |
| Attack | `skeleton-attack` | 9 | `skeleton-attack_0.png` ... `skeleton-attack_8.png` |

This is a folder reference in the Xcode project (blue, not yellow), so
anything placed here is picked up automatically at build time — no
project file edits needed. Note that it preserves this nested path inside
the app bundle (`Assets/Enemies/Zombie/...`), which is why
`AssetProvider.resolveImage` looks these up via
`Bundle.main.url(forResource:withExtension:subdirectory:)` rather than a
bare `UIImage(named:)` — see the README at the repo root ("Bundle path
bug") for why that distinction matters.

If any frame in a sequence is ever missing (e.g. replacing these with a
different set), `Walker` cleanly falls back to a placeholder circle with
no animation rather than animating through blank frames — it checks every
frame in a sequence up front before switching over.

There is intentionally no death animation in this set — on death, Walker
plays a 0.25s scale-down + fade-out (code, not sprite frames) and removes
itself.
