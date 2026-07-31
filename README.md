# 2D Zombie Survival (iOS)

A top-down, twin-stick zombie survival shooter foundation, built with
SpriteKit for iOS 17+. This phase is core loop only: move, aim, shoot,
survive rounds, die, see how far you got. No shop, no saves, no menus —
but the architecture is laid out so those slot in later without rewrites.

## Running it

1. Open `ZombieSurvival.xcodeproj` in Xcode 15+ (macOS required — this
   project was built and reviewed in a Linux environment without Xcode, so
   it has not been compiled by `xcodebuild`; open it and fix up anything
   Xcode's opening process flags before your first run).
2. Pick the `ZombieSurvival` scheme and any iOS 17+ simulator (iPhone or
   iPad), or a real device with your team selected under Signing.
3. Run. The game is landscape-only (twin-stick controls need the width).
   - **Left half of the screen**: virtual joystick, moves the player.
   - **Right half of the screen**: virtual joystick, aims and fires the
     pistol continuously while held.
4. Tap **Next Round** to start Round 1 (and every round after — there's no
   auto-advance, the requirement is deliberate).

## Architecture

| File | Responsibility |
|---|---|
| `Config/Balance.swift` | Every tuning number (health curve, spawn counts, speeds, damage, fire rate, joystick feel). Rebalance the whole game from this one file. |
| `State/GameState.swift` | Serializable (`Codable`) snapshot of a run: round, health, ammo, control scheme. No save/load system reads or writes it yet — it exists so one can be added later without restructuring. |
| `Controls/ControlScheme.swift` | Protocol abstracting "how touches become movement/aim/fire." `ControlSchemeFactory` switches on `ControlSchemeType`. |
| `Controls/VirtualJoystick.swift` | Reusable floating joystick node (appears where touched, tracks drag, fades out on release). |
| `Controls/DualStickControlScheme.swift` | The active default: left-half joystick moves, right-half joystick aims + continuous-fires. |
| `Controls/SingleStickAutoAimControlScheme.swift` | A second, functioning `ControlScheme` implementation (single movement stick, auto-aims and fires at the nearest zombie). Not reachable in-game yet since there's no settings UI — swap it in via `ControlSchemeFactory` once one exists. |
| `Entities/Player.swift` | Health, move speed, facing, holds a `Pistol`. |
| `Entities/Weapon.swift` | `Weapon` protocol + `Pistol`: magazine size, fire rate, reload timer, infinite reserve ammo (reload always tops the mag back up). |
| `Entities/Bullet.swift` | A traveling projectile; range and motion are simulated manually each frame (simple circle-vs-circle hit test), not via SpriteKit physics. |
| `Entities/Enemy.swift` | `Enemy` protocol — health, contact damage, attack cooldown, pathing hook. New enemy types are new files conforming to this. |
| `Entities/Walker.swift` | The one enemy type this phase ships: walks straight at the player, damages on contact, respects an attack cooldown. |
| `Systems/WaveManager.swift` | Round progression and the spawn queue: queues up a round's full enemy count, caps concurrent alive enemies at 25, and refills the cap as enemies die. Round only ends (and only then does "Next Round" appear) once the queue is empty and every spawned enemy is dead. |
| `Scenes/GameScene.swift` | Wires everything together: owns the update loop, touch routing, bullet/enemy collision, HUD refresh, round transitions, game over. |
| `HUD/HUD.swift` | Health bar, round counter, ammo counter, "Next Round" button, game-over overlay (Restart works; Main Menu is stubbed). |
| `Support/AssetProvider.swift` | Centralized, swappable node factory — see below. |

## Placeholder art / how to drop in real sprites

Every entity (player, walker, bullet) is currently a colored `SKShapeNode`
circle. All of that goes through `AssetProvider.makeNode(for:radius:fillColor:)`
in `Support/AssetProvider.swift` — nothing else in the codebase creates
these nodes directly.

To swap in real art:

- Add an image named `player`, `walker`, or `bullet` to `Assets.xcassets`
  (or drop it into `ZombieSurvival/Assets/`, a folder reference that's
  already wired into the Xcode project — see `Assets/README.md`).
- `AssetProvider` checks for a matching image first and only falls back to
  the placeholder shape if none exists. No other code changes needed.
- Adding a new entity type later (new enemy, new weapon pickup, etc.)?
  Add a case to `EntityVisualKind` and follow the same naming convention.

## Balance as implemented

- Zombie health: 150 base, +100 per round through round 9 (round 9 = 950),
  then ×1.1 compounding each round after (`Balance.zombieHealth(forRound:)`).
- Enemy count per round: `6 + (round - 1) * 3` (`Balance.enemyCount(forRound:)`)
  — tune freely, it's the one formula in `Balance.swift` most likely to
  need a pass once real playtesting starts.
- Max concurrent alive enemies: 25, enforced by `WaveManager`.
- Pistol: 12-round magazine, 0.22s between shots, 1.4s reload, infinite
  reserve ammo.

## What's stubbed / simplified in this phase

- **No shop, no saves, no menus.** `GameState` is `Codable` and ready for
  a save system, but nothing persists it yet.
- **Game over buttons**: "Restart" reloads a fresh `GameScene`. "Main Menu"
  is a no-op tap target — there's no menu to go to yet.
- **Single-stick + auto-aim control scheme** is fully implemented and
  functional (`SingleStickAutoAimControlScheme`), but there's no settings
  screen to select it from yet — it's wired for a future switch, not for
  players to reach today.
- **One enemy type** (Walker). `Enemy` is a protocol specifically so a
  Runner, Spitter, etc. can be added as new files later.
- **Straight-line pursuit**, not real pathfinding/navmesh — fine for a
  single open arena; would need revisiting if obstacles are added.
- **Bounded single-screen arena**, no camera scrolling/world larger than
  the screen. Player movement is clamped to the visible arena.
- **Bullets and enemies use manual circle-vs-circle collision checks**
  each frame rather than SpriteKit physics bodies/contact delegate —
  simpler to reason about at these entity counts (≤25 enemies, a handful
  of bullets).
- Not compiled with `xcodebuild`/Xcode in this environment (Linux, no
  Apple toolchain available) — the project file was generated
  programmatically and reviewed by hand, but give it a first build in
  Xcode before relying on it.
