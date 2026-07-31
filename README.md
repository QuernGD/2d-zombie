# 2D Zombie Survival (iOS)

A top-down, twin-stick zombie survival shooter built with SpriteKit for
iOS 17+. Phase 1 was the core loop (move/aim/shoot/survive rounds/die).
Phase 2 added the economy: coins, a round-end shop, 8 weapons, overclocking,
perks, and animated zombie sprites. Phase 3 (this pass) adds a save system
(3 manual-save slots), a real main menu, map/difficulty select, a full
settings screen, and an in-run pause menu.

## Zombie sprites are live

The `skeleton-idle`/`skeleton-move`/`skeleton-attack` frames arrived and
are checked into `ZombieSurvival/Assets/Enemies/Zombie/`. Getting them to
actually resolve at runtime surfaced a real bug (see "Bundle path bug"
below) — it's fixed, and `Walker` now animates idle/move/attack from real
art instead of the placeholder circle.

## Running it

1. Open `ZombieSurvival.xcodeproj` in Xcode 15+ (macOS required — built and
   reviewed in a Linux environment without Xcode, so it hasn't been
   compiled by `xcodebuild`; open it and fix up anything Xcode's opening
   process flags before your first run).
2. Pick the `ZombieSurvival` scheme and any iOS 17+ simulator (iPhone or
   iPad), or a real device with your team selected under Signing.
3. Run. The app opens on the **Main Menu**: Play (→ map/difficulty select →
   new run), Load Game (3 slots), Settings.
4. In a run, the game is landscape-only.
   - **Left half of the screen**: virtual joystick, moves the player (or,
     with Single Stick + Auto-Aim selected in Settings, just movement —
     aim/fire is automatic).
   - **Right half of the screen**: virtual joystick, aims and fires the
     active weapon continuously while held (dual-stick mode only).
5. Tap **Next Round** to start (every round, including the first — no
   auto-advance). **Shop** and **Pause** are both available alongside it —
   Shop only at round breaks, Pause any time during a round.
6. In the shop: buy weapons, a Mystery Crate, an ammo refill, an Overclock
   upgrade for your equipped weapon, a perk, or open Settings. **Close**
   returns to the game exactly as you left it.
7. In the pause menu: Resume, Settings, **Save Game** (pick one of 3
   slots), or Quit to Menu.
8. On death: **Restart** (fresh run, same map/difficulty), **Restart from
   Last Save** (greyed out if you've never saved), or **Quit**.

## Architecture — Phase 1 (unchanged)

| File | Responsibility |
|---|---|
| `Config/Balance.swift` | Every tuning number. Rebalance the whole game from this one file. |
| `State/GameState.swift` | Serializable (`Codable`) snapshot of a run, SpriteKit-free — read/written directly by `SaveManager` as of Phase 3. |
| `Controls/*.swift` | `ControlScheme` abstraction (dual-stick or single-stick+auto-aim, switchable live from Settings as of Phase 3). |
| `Entities/Enemy.swift` | `Enemy` protocol — new enemy types are new files. |
| `Entities/Walker.swift` | The one enemy type: pursues the player, contact damage on a cooldown. Now also animated (see below). |
| `Systems/WaveManager.swift` | Round progression and the spawn queue (25 concurrent cap, refills as enemies die). |
| `Scenes/GameScene.swift` | Owns the update loop, touch routing, collision, HUD refresh, round transitions, game over. |
| `HUD/HUD.swift` | On-screen health/round/ammo/etc. and every button. |
| `Support/AssetProvider.swift` | Centralized, swappable node factory (placeholder shapes ↔ real sprites). |

## Architecture — Phase 2 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Entities/Weapon.swift` | `Weapon` protocol (extended — see below) + `BaseWeapon` (shared fire/reload/damage logic) + `Pistol`. |
| `Entities/WeaponInventory.swift` | `WeaponType` catalog enum (cost, display name, `makeWeapon()`) + `WeaponInventory` (2 slots, active index, swap, perk-multiplier refresh). |
| `Entities/SMG.swift`, `Shotgun.swift`, `AssaultRifle.swift`, `Sniper.swift`, `LMG.swift`, `GrenadeLauncher.swift`, `ArcCannon.swift` | One tiny `BaseWeapon` subclass per weapon — just stats, plus a `bulletBehavior` override for the two special ones. |
| `Entities/Perk.swift` | The 4 one-time run perks (Vitality, Rapid Hands, Overdrive, Sprinter). |
| `Entities/CoinPickup.swift` | Dropped coin node; magnet pull, collection, and round-end auto-fly all live in `GameScene`. |
| `Systems/EconomyManager.swift` | Coin balance, spend/afford checks, Mystery Crate weighted roll. |
| `Scenes/ShopScene.swift` | The shop overlay — its own `SKScene` so `GameScene` can be fully paused (not ticking, not unloaded, not recreated) while it's up. |

### The Weapon protocol refactor

Added `name`, `cost`, `reloadTime`, `pelletCount`, `spreadAngle`, moved
`startReload(at:)` into the protocol, and made `damage` a computed
`baseDamage * overclockMultiplier`. Beyond that literal list, a few more
additions turned out to be necessary plumbing (called out here since they
weren't explicitly requested):

- `weaponType: WeaponType` — lets code map a live weapon instance back to
  its catalog identity (ownership checks, GameState persistence) without
  fragile name-string matching.
- `overclockMultiplier`, `fireRateMultiplier`, `reloadTimeMultiplier` —
  `fireRateMultiplier`/`reloadTimeMultiplier` are perk-only (Overdrive,
  Rapid Hands); Overclock Tier 2's own +25% fire rate is computed
  internally from `overclockTier` and never flows through the multiplier,
  so the two bonuses can't accidentally double-stack.
- `bulletBehavior: BulletBehavior` — tells `GameScene` whether to spawn a
  standard bullet, an AoE explosive, or a chaining bolt, without type-
  checking the weapon class.
- `refillMagazine()` — needed for the shop's Ammo Refill item.

### Pause safety

`GameScene` now runs a `gameClock` that only advances while `!isPaused`,
clamped per-frame to `Balance.maxDeltaTime` (0.05s). Every timer (fire
rate, reload, attack cooldown, spawn interval) is driven off `gameClock`
instead of SpriteKit's real-time `currentTime`. Opening the shop sets
`isPaused = true` and presents `ShopScene` (which holds a strong reference
to the same `GameScene` instance); closing it flips `isPaused` back and
re-presents that instance. Nothing is recreated, so weapons/perks/coins/
round state survive untouched.

One non-obvious bug this surfaced and fixed: SpriteKit calls
`didMove(to:)` **every** time a scene is presented, including
re-presenting an already-used instance. Without a `didSetup` guard,
returning from the shop would have silently rebuilt `Player` and
`WaveManager` from scratch. `GameScene.didSetup` guards against that.

### Coins

Base 25, +5 per round (`Balance.coinValue(forRound:)`). Player has a 60pt
magnet radius that pulls nearby coins in; anything within ~26pt is
collected outright. At round end, every coin still on the field is
credited immediately (nothing is lost) and sent flying to the player as a
purely visual flourish — the credit doesn't wait on the animation.

### Weapons & Overclock

All 8 from the spec, infinite reserve ammo, magazines still reload.
Overclock Station upgrades **whichever weapon is currently equipped**
(Tier 1: 5,000/2×, Tier 2: 12,500/3.5×+25% fire rate) — the shop also has
a "Swap Active" button so you can overclock your off-hand weapon without
leaving the shop.

### Shop judgment calls worth knowing about

- **Buying a weapon with both slots full** prompts which slot to replace,
  and is **not charged** until a slot is confirmed — canceling costs
  nothing.
- **Mystery Crate is charged upfront** (it's a gamble). If the roll lands
  on a type you don't have room for, you still get to choose which slot it
  replaces, but canceling that choice does **not** refund the crate —
  you already paid for the roll. This is a genuine "lose the coins" trap
  if you decline; flagging it because it's the one purchase flow where
  canceling has a real cost.
- **Mystery Crate can roll a weapon you already own** into your other
  slot (it's weighted rarer, not excluded). `GameScene.syncGameState()`
  handles that safely — the `WeaponType → overclockTier` dictionary keeps
  the higher tier on a duplicate key instead of crashing.
- The shop's layout is a fixed, non-scrolling grid — comfortable on iPad
  landscape, tight on smaller iPhones. A scrollable list would be the
  right follow-up; out of scope for this pass.

### Zombie animation

`Walker` loads `skeleton-idle_0...16`, `skeleton-move_0...16`,
`skeleton-attack_0...8` from `Assets/Enemies/Zombie/` and drives
idle/move/attack off of them. No death animation was supplied — on death,
`Walker` plays a code-driven 0.25s scale-down + fade-out and removes
itself, exactly as asked. All three animation sequences load up-front
per-instance and gracefully no-op back to the placeholder circle if any
frame in a sequence is missing, so a partial art drop never animates
through blank frames or gets a zombie stuck mid-animation.

#### Bundle path bug (found and fixed while wiring the real art in)

`ZombieSurvival/Assets/` is an Xcode **folder reference** (blue folder),
which — unlike a group — preserves its on-disk directory structure inside
the built app bundle instead of flattening it. That means
`Assets/Enemies/Zombie/skeleton-idle_0.png` lands at that same nested path
inside the bundle, not at the bundle root. `UIImage(named:)` with a bare
filename only searches the bundle root and compiled asset catalogs
(`Assets.xcassets`) — it does **not** recursively search subdirectories,
so the original `UIImage(named: "skeleton-idle_0")` lookup would have
silently failed once real frames existed, even though everything looked
correctly wired.

Fixed in `AssetProvider.resolveImage`: it now tries
`Bundle.main.url(forResource:withExtension:subdirectory:)` with the
frame's actual bundle-relative folder first (`Assets/Enemies/Zombie` for
the zombie, `Assets` for anything dropped loose at the top level), and
only falls back to the bare `UIImage(named:)` lookup, which is what
actually resolves `Assets.xcassets` entries. `AnimationFrameSequence` grew
an optional `subdirectory` field to carry this. This also retroactively
fixes the same latent bug for `player`/`walker`/`bullet`/`coin` if anyone
drops a loose image straight into `Assets/` rather than into
`Assets.xcassets`.

## Architecture — Phase 3 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Systems/SaveSlot.swift` | Lightweight `Codable` summary (round, coins, timestamp) — the thing LoadGameScene actually reads to list slots cheaply. |
| `Systems/SaveManager.swift` | FileManager-backed persistence in the Documents directory: one state JSON + one summary JSON per slot, `mostRecentSlot()`, `hasAnySave()`. Manual save only — nothing in this codebase calls `save` except the Pause menu's "Save Game" button. |
| `Systems/SettingsStore.swift` | Global, cross-run settings in UserDefaults (never GameState/SaveManager). Also hosts `Difficulty` and `ParticleDensity`/`FrameCap` — small enough not to need their own files. |
| `Systems/AudioManager.swift` | `AudioManager` protocol + `StubAudioManager` (no-op) + swappable `AudioManagerProvider.shared`. |
| `Scenes/MainMenuScene.swift` | App entry point. Play / Load Game / Settings. |
| `Scenes/MapSelectScene.swift` | Map + difficulty picker shown before a new run starts. Also hosts `MapID`. |
| `Scenes/LoadGameScene.swift` | Lists the 3 save slots via `SaveSlot` summaries; loads a slot into a fresh `GameScene`. |
| `Scenes/SettingsScene.swift` | Audio/Graphics/Controls/Difficulty, reachable from the main menu, the shop, and the pause menu. |
| `Scenes/PauseMenuScene.swift` | In-run pause: Resume, Settings, Save Game (inline 3-slot picker), Quit to Menu. Same pause mechanism as the shop. |

### Save system

Exactly what was asked: 3 slots, manual save only (the only call to
`SaveManager.save` in the entire codebase is the Pause menu's "Save Game"
button — there is no autosave anywhere), one JSON file per slot in the
Documents directory via `Codable` + `FileManager`, plus a separate
lightweight `SaveSlot` summary file per slot so `LoadGameScene` never has
to deserialize a full run just to show a list.

**Timer reset on load, guaranteed by construction, not special-cased.**
Loading a save always builds a **brand-new** `GameScene` (via
`configureRestoring(_:)`, called before the scene is first presented) —
never resurrects timer state onto a live instance. That one design choice
gets the entire "critical" requirement for free:
- `gameClock` starts at 0 because it's a fresh instance's stored property.
- Every weapon is rebuilt via `WeaponType.makeWeapon()` — a fresh object,
  so `lastFireTime`/`reloadStartTime` start at their defaults. Each
  restored weapon also gets an explicit `refillMagazine()` call, so it
  always loads with a full magazine and not-reloading regardless of what
  was true at save time.
- `WaveManager` is a fresh instance too, so `lastSpawnTime` and the alive-
  enemy set start empty. `restoreRound(_:)` sets `currentRound` so the
  *next* "Next Round" tap lands exactly on the saved round — the round is
  refought fresh, since no enemies or mid-combat state is ever restored.
- No enemies exist at load time, full stop — `enemies` is a fresh empty
  array on a fresh scene.

The other thing this surfaced and fixed: **SpriteKit calls `didMove(to:)`
every time a scene is presented**, including re-presenting an
already-set-up instance (this bit Phase 2's shop too — see below). A
`didSetup` guard makes `GameScene`'s one-time setup actually one-time.

### Main menu, map/difficulty, settings, pause

- **Map select** offers both maps, unlocked, no cost — see the map-parity
  callout below.
- **Difficulty** (Easy 0.75× / Medium 1.0× / Hard 1.35×) is a single
  multiplier applied to both zombie health and contact damage
  (`WaveManager.difficulty`, read once at scene setup). It's chosen at
  Map Select (which just edits the same `SettingsStore.difficulty`
  preference Settings shows) and baked into that run's `GameState` —
  SettingsScene shows it read-only, labeled "locked for this run," the
  moment it's opened mid-run.
- **Controls**: switching Dual Stick ↔ Single Stick + Auto-Aim in
  Settings takes effect immediately. `GameScene.refreshControlSchemeIfNeeded()`
  is called every time you return to gameplay from the shop or pause menu,
  tears down the old joystick nodes, and installs the new scheme's — this
  is also what finally makes `SingleStickAutoAimControlScheme` (built in
  Phase 1, never reachable) actually reachable.
- **Pause** is a new HUD button, visible for the entire run (not just
  round breaks, unlike Next Round/Shop), using the exact same
  pause-without-unloading mechanism as the shop.
- **Game over** now offers three real options instead of one working +
  one stub: Restart (fresh run, same map/difficulty), Restart from Last
  Save (greyed out via `SaveManager.hasAnySave()` if you've never saved),
  Quit (→ Main Menu, replacing the old stubbed "Main Menu" button).

### Judgment calls worth knowing about

- **Map parity.** Both maps are fully selectable and functional, but they
  currently share identical arena geometry and spawn layout — the only
  difference is a background tint (`MapID.backgroundColor`). Saying so
  directly rather than pretending there's more variety than there is.
- **Difficulty is set in two places, but it's one preference.** Map Select
  and Settings both read/write the same `SettingsStore.difficulty` — there
  isn't a separate "run setup" value distinct from the "global default."
  Only the run's own `GameState.difficulty` snapshot is actually locked.
- **Volume controls are stepped, not a continuous drag slider** (5
  discrete levels, tap a segment to set it). SpriteKit has no built-in
  slider widget; a real drag-tracked one felt like more UI investment than
  this pass justified. `Balance.volumeSliderSteps` controls the step count.
- **No audio playback system exists in this project.** Master/SFX volume
  and mute are fully wired end-to-end — they persist to `SettingsStore`
  *and* call through `AudioManagerProvider.shared` (a couple of
  `playSFX(...)` calls exist in `GameScene`, e.g. on weapon fire and
  zombie death) — but `StubAudioManager` is a genuine no-op, not a fake
  player. Swap `AudioManagerProvider.shared` for a real implementation
  later; no call site changes.
- **Particle density, blood effects, screen shake, and damage numbers are
  in the same boat as audio**, one level further: none of those systems
  exist in the codebase *at all* yet (no particle emitters, no floating
  damage numbers, no camera shake), so these Settings toggles persist to
  `SettingsStore` but have nothing to flip yet. Not fabricated, just
  honestly inert until those systems exist.
- **Frame cap applies at next launch, not live.** `SpriteView`'s
  `preferredFramesPerSecond` is a SwiftUI-level parameter read once in
  `GameContainerView`; there's no observable bridge from a SpriteKit
  scene's Settings change back up to SwiftUI in this codebase. Changing it
  persists correctly and takes effect the next time the app launches.
- **Restarting after death does not carry over difficulty from a loaded
  save differently than a fresh run** — "Restart" always keeps whatever
  map/difficulty the just-ended run had, whether that run was fresh or
  loaded from a save. Coins/weapons/perks never carry over on Restart
  either way, per spec.
- **Save Game has no overwrite confirmation** — tapping a slot in the
  pause menu's save picker overwrites it immediately (with a brief
  "Saved to Slot N" toast), including a non-empty slot. Kept simple
  deliberately; a confirm-overwrite step would be the natural next
  addition.

## Balance as implemented (Phase 1, unchanged)

- Zombie health: 150 base, +100 per round through round 9 (round 9 = 950),
  then ×1.1 compounding each round after.
- Enemy count per round: `6 + (round - 1) * 3`.
- Max concurrent alive enemies: 25.
- Pistol: 12-round magazine, 0.22s between shots, 1.4s reload.

All Phase 2 weapon/coin/overclock/perk numbers are placeholders in
`Balance.swift` — tune freely, nothing else depends on the exact values.

## What's stubbed / simplified

- **Audio, particle density, blood, screen shake, damage numbers**: settings
  UI and persistence are real; the underlying systems don't exist yet (see
  the Phase 3 judgment calls above for specifics on each).
- **Frame cap**: persists correctly, applies at next app launch rather than
  live (see above).
- **Map variety**: both maps are selectable and playable; they currently
  share identical geometry, differing only in background tint.
- **Meta-progression**: coins, weapons, and perks never carry over between
  runs (Restart or a brand new run) — every run starts from Phase 2's
  baseline aside from map/difficulty. No meta-progression system was
  specified.
- **One enemy type**, **straight-line pursuit**, **single-screen arena**,
  **manual circle-vs-circle collision** — all unchanged from Phase 1, see
  prior notes; none of this pass touched them.
- **Chain (Arc Cannon) and AoE (Grenade Launcher) visuals** are minimal
  placeholder flourishes (a fading ring / a fading line) — functional, not
  polished.
- **Shop and Settings layouts are fixed, non-scrolling grids** — comfortable
  on iPad landscape, tight on smaller iPhones. A scrollable list would be
  the natural follow-up for both; out of scope for this pass.
- Not compiled with `xcodebuild`/Xcode in this environment (Linux, no
  Apple toolchain) — reviewed carefully by hand (including catching and
  fixing two real bugs along the way: the `didMove(to:)` re-presentation
  issue and a Walker animation state that could get permanently stuck if
  only some frame sequences were missing), but give it a first real build
  in Xcode before relying on it.
