# 2D Zombie Survival (iOS)

> ## ⚠️ Branch: `fps-raycaster`
>
> This branch converts the game from top-down 2D to a **first-person
> raycaster** (Wolfenstein 3D style). `main` is untouched.
>
> This is **ray casting, not ray tracing** — no reflections, no light
> bounces, no Metal. It's fake 3D projected from the same 2D grid the
> top-down build used, with enemies drawn as camera-facing sprite
> billboards. That's the right fit here precisely *because* all the art is
> 2D pixel art: the zombies become billboards exactly the way Doom's
> monsters were.
>
> Everything above the renderer carried over unedited: WaveManager,
> EconomyManager, SaveManager/SaveSlot, SettingsStore, AudioManager,
> GameState, Balance, Perk, WeaponInventory, every weapon class and its
> stats, AssetProvider, and all of MainMenu/MapSelect/LoadGame/Pause/Shop.
> Rounds, coins, the shop, perks, saves and difficulty all behave
> identically. See the **First-person conversion** section below for the
> full write-up, the performance dial, and what's stubbed.

A top-down, twin-stick zombie survival shooter built with SpriteKit for
iOS 17+. Phase 1 was the core loop (move/aim/shoot/survive rounds/die).
Phase 2 added the economy: coins, a round-end shop, 8 weapons, overclocking,
perks, and animated zombie sprites. Phase 3 added a save system (3
manual-save slots), a real main menu, map/difficulty select, a full
settings screen, and an in-run pause menu. Phase 4 replaced all of
Phase 2's placeholder/skeleton art with a full spritesheet-based art pack:
real Player/Zombie(x4) character animations, weapon fire animations,
tile-based arenas for both maps, 9-sliced UI panels, and a real coin icon.
Phase 5 added a CI pipeline that builds an unsigned, sideloadable IPA on
every push. Phase 6 added wall/obstacle collision and fixed a dual-stick
control bug. Phase 8 (this pass) replaces the procedural map layouts with
hand-designed ASCII arenas, gives enemies real flow-field pathfinding, and
fixes zombies spawning inside solid geometry.

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

### Zombie animation (superseded by Phase 4 — kept for history)

Originally `Walker` loaded `skeleton-idle_0...16`, `skeleton-move_0...16`,
`skeleton-attack_0...8` from `Assets/Enemies/Zombie/` (now removed — see
the Phase 4 section below for the real character-sheet-based animation
that replaced this).

#### Bundle path bug (found and fixed while wiring the real art in)

`ZombieSurvival/Assets/` is an Xcode **folder reference** (blue folder),
which — unlike a group — preserves its on-disk directory structure inside
the built app bundle instead of flattening it. That means a file at
`Assets/<subfolder>/<name>.png` lands at that same nested path inside the
bundle, not at the bundle root. `UIImage(named:)` with a bare filename
only searches the bundle root and compiled asset catalogs
(`Assets.xcassets`) — it does **not** recursively search subdirectories,
so a bare `UIImage(named: "skeleton-idle_0")` lookup silently failed once
real frames existed, even though everything looked correctly wired.

Fixed in `AssetProvider.resolveImage`: it now tries
`Bundle.main.url(forResource:withExtension:subdirectory:)` with the
image's actual bundle-relative folder first, and only falls back to the
bare `UIImage(named:)` lookup, which is what actually resolves
`Assets.xcassets` entries. `AnimationFrameSequence` (and, as of Phase 4,
`SpriteSheetFrames`) carry an optional `subdirectory` field for this. This
also retroactively fixes the same latent bug for `player`/`walker`/`bullet`
if anyone drops a loose image straight into `Assets/` rather than into
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

## Architecture — Phase 4 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Support/AssetProvider.swift` | Extended with `SpriteSheetFrames` + `loadSpriteSheetTextures` (horizontal-strip slicer) and `makeAnimatedNode(sheet:size:fallbackColor:)`, plus `loadTileTexture` (grid-cell extractor) and `makeResizablePanel` (9-slice via `SKSpriteNode.centerRect`). All reuse the same `resolveImage` bundle-path lookup as the Phase 2 numbered-frame path, which is left fully intact for backward compatibility. Every texture handed out now also gets `.filteringMode = .nearest`, fixing blurry-scaled pixel art. |
| `Systems/TileMapBuilder.swift` | New. Builds a tile-based arena (floor/wall/obstacle layout) from the Wasteland or Interior tileset per map. |
| `Entities/Walker.swift` | Rewritten: `zombieVariant: Int` (1-4, random per spawn), loads idle/run/hit/knocked/death(s) from `Assets/Characters/Zombie<variant>/`, plays a real death animation (falls back to the old scale+fade only if a variant's frames fail to load). |
| `Entities/Player.swift` | Same idle/run/hit/death animation treatment from `Assets/Characters/Player/`, plus a small weapon-fire overlay sprite that plays the active weapon's `_Shoot` animation once per shot. |
| `Entities/WeaponInventory.swift` | `WeaponType` gained a `shootSheet` computed property mapping each of the 8 weapon types to one of 6 `_Shoot` sheets (see below). |
| `Entities/CoinPickup.swift` | Now renders the Items pack's "Scraps" icon (`Assets/Items/coin.png`) via the new sheet-animation path instead of a plain yellow circle. |
| `HUD/HUD.swift`, `Scenes/ShopScene.swift`, `Scenes/SettingsScene.swift`, `Scenes/PauseMenuScene.swift` | Health bar and dialog backgrounds now use 9-sliced `panel1`/`panel2` art and color-swatch health fill textures instead of flat `SKShapeNode` fills. |

### Spritesheet support

Every Phase 4 art file (characters, weapons, effects, items) ships as a
single horizontal-strip sheet: fixed-size square frames side by side, no
padding, so `frame count = sheet width ÷ frame size`. `AssetProvider` slices
these with `CGImage.cropping(to:)` in `loadSpriteSheetTextures`, which — per
the brief's explicit instruction — reuses the exact same `resolveImage`
bundle-path lookup as the Phase 2 numbered-frame loader, so folder-reference
pathing works identically for both. The old `AnimationFrameSequence` /
`loadTextures` / `makeAnimatedNode(for:frames:radius:fillColor:)` path is
untouched and still compiles; it just has no callers left now that
Walker/Player have moved to sheets.

Tilesets use a different extractor, `loadTileTexture(sheetName:subdirectory:tileSize:column:row:)`,
since they're addressed by (column, row) grid cell rather than a single
horizontal frame index.

### Frame-count discrepancies vs. the brief

Several of the delivered files don't match the brief's stated frame counts.
Measured directly (via `file` + visual inspection) and used as ground
truth instead of the brief's numbers:

| Sheet | Brief said | Measured (used) |
|---|---|---|
| Bullet impact (20x20) | 3 frames | **5 frames** (100x20) |
| Explosion (48x48) | 10 frames | **7 frames** (336x48) |
| Pop-up 1/2/3 (20x20) | 3 frames each | **5 frames** each (100x20) |
| Items (16x16) | 3 frames each | **7 frames** each (112x16), and there are 23 items, not 21 |

Character sheets (Player + Zombie1-4, all idle/run/hit/knocked/death) and
weapon `_Shoot` sheets matched the brief exactly.

### Zombie variant → enemy tier

**There is no tier mapping** — Walker is still the only enemy type (no
Runner/Brute/Spitter subclasses exist), so `zombieVariant` (1-4) is
assigned **randomly per spawn** rather than tied to any tier. If/when
enemy tiers are introduced, mapping a tier to a variant would be a small
change in `WaveManager.spawnOne()`.

### Hit vs. Knocked (a judgment call, since no zombie "attack" sheet exists)

The delivered character sheets have Idle/Run/Hit/Knocked/Death — no
"attack" sheet. So contact damage (the zombie biting the player) still has
no unique animation, exactly as in Phases 1-3 — it's pure instant math.
Hit and Knocked were repurposed instead as damage-*reaction* flinches on
the zombie itself: a single hit dealing at least `Balance.zombieKnockedDamageThreshold`
(50) damage plays Knocked, anything lighter plays Hit. Player only got Hit
wired (the brief lists no `Player_knocked` sheet).

### Weapon `_Shoot` → `WeaponType` mapping

Only 6 unique `_Shoot` sheets exist for 8 weapon types, so two reuse
another weapon's sheet:

| WeaponType | Sheet used | Note |
|---|---|---|
| pistol | `pistol_shoot` | exact |
| shotgun | `shotgun_shoot` (Pump) | exact |
| assaultRifle | `rifle_shoot` | exact |
| sniper | `sniper_shoot` | exact |
| grenadeLauncher | `rocketlauncher_shoot` | closest fit (explosive launcher) |
| smg | `revolver_shoot` | **reused** — no dedicated SMG sheet |
| lmg | `rifle_shoot` | **reused** — shared with assaultRifle (long-gun family) |
| arcCannon | `sniper_shoot` | **reused** — shared with sniper (precision/beam motif) |

`_Flicker` sheets (one per weapon, plus a melee-only `Axe_Flicker`) were
**not wired**. Every `_Flicker` sheet measures the same 7 frames (224x32),
including the melee axe's — a melee weapon has no muzzle, so a uniform
frame count across melee and ranged reads as a shared idle/glow effect
rather than a muzzle flash. Not worth wiring on that evidence.

### Tile-based arenas — best-guess tile indices, please verify in Xcode

Neither `Wasteland_Tileset_32x32.png` (9x19 tiles) nor
`Interior_Tileset_32x32.png` (10x17 tiles) ships with a documented
tile-index legend. The floor/wall/obstacle column/row picks in
`Balance.swift` (`wastelandFloorTile`, `interiorWallTile`, etc.) are an
honest best-effort guess from eyeballing the rendered sheets, **not
verified pixel-exact** — treat them as a starting point to look at in
Xcode and adjust, not as ground truth. They're isolated to a handful of
`TileCoord` constants specifically so nudging them is a one-line change
per tile role.

`TileMapBuilder` draws a full floor grid, a wall ring around the border,
and a handful of scattered obstacle tiles at fixed fractional positions.
**As of Phase 6, walls and obstacles are solid** — see the Phase 6 section
below for how collision was added.

Map-to-tileset assignment: `.original` ("The Yard") → Wasteland,
`.facility` ("The Facility") → Interior. Both maps have genuinely
different geometry, unlike Phase 3 (background tint only). The map was
called "Ashyard" until Phase 8 renamed it to match its indoor visuals.

### UI: 9-sliced panels + health bar

`AssetProvider.makeResizablePanel` wraps `SKSpriteNode.centerRect` so
`panel1.png`/`panel2.png` (96x96, a clean 3x3 grid of 32px cells) stretch
only in the middle, keeping their riveted-metal corners crisp at any size.
Applied to: the HUD health bar background, and a full dialog background in
`ShopScene`/`PauseMenuScene` (panel1) and `SettingsScene` (panel2, for
visual variety). The health bar *fill* instead uses `health_bar_fillers.png`
(4 solid 64x64 color swatches: red/maroon, blue, orange/brown, green) —
solid color needs no 9-slicing, so it's just scaled via `xScale` the same
way the old `SKShapeNode` fill was, swapping texture at the same
healthy/medium/critical thresholds the HUD already used. Both paths fall
back to the pre-Phase-4 plain-shape look if their sheet fails to load.
HUD ammo/health icons (mentioned as "if useful" in the brief) were **not**
added — the existing text-based ammo counter was already clear, and icons
would have meant reworking the HUD's tight label layout for a
nice-to-have; skipped to keep this pass scoped.

### Coin icon

No literal coin exists in the Items pack. Used **Scraps** (a grey/silver
metal-scrap-pile icon) rather than the brief's suggested "blueprint" —
loose metal scrap reads more like currency than a document icon. Like
every Items sheet it's actually a short animated strip (7 frames), not a
static image, so `CoinPickup` now plays it via the sheet-animation path.
This also incidentally fixed a real path bug: the old `AssetProvider.makeNode(for:.coin,...)`
hardcoded the top-level `Assets/` folder for every `EntityVisualKind`,
which would never have found `coin.png` at `Assets/Items/coin.png` — fixed
by having `CoinPickup` call the sheet API directly with an explicit
subdirectory, bypassing that hardcoded path entirely (and removing the
now-unused `.coin` case from `EntityVisualKind`).

### Manual verification still needed in Xcode

- **Tile indices** (floor/wall/obstacle column/row for both tilesets) —
  the single biggest thing to eyeball; see above.
- **Weapon fire overlay positioning/scale** — the muzzle sprite is placed
  at a fixed offset forward of the player; whether it reads well at actual
  device resolution needs a look.
- **Zombie/Player animation frame timings** (`Balance.characterIdleFrameTime`
  etc.) are reasonable guesses, not motion-tested.
- **9-slice panel `centerRect`** assumes a clean 32px-bordered 3x3 grid on
  a 96x96 sheet — worth a visual check that the corners don't look
  stretched.
- General **first real build/run** — this environment has no Xcode/
  `xcodebuild`, so none of Phase 4 has been compiled or run on a simulator;
  everything above was verified by direct pixel measurement and careful
  manual code review only.

## Architecture — Phase 6 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Support/Geometry.swift` | Adds `circleIntersectsAnyRect` and `resolveCollision(from:to:radius:solidRects:)` — shared axis-separated circle-vs-rects collision, used by both `Player.move` and `Walker.update`. |
| `Systems/TileMapBuilder.swift` | `build(for:size:)` now returns a `Result(node:solidRects:)` instead of a bare node — every wall/obstacle tile placed contributes its world-space rect. Each map also gets its own distinct `obstacleLayout` (see below) instead of sharing one fractional pattern. |
| `Entities/Enemy.swift`, `Entities/Walker.swift`, `Entities/Player.swift` | `update`/`move` now take a `solidRects: [CGRect]` parameter and resolve movement against it. |
| `Scenes/GameScene.swift` | Stores `solidRects` (captured from `TileMapBuilder.build` in `setupArena`) and passes it to both `player.move` and `enemy.update`. Also sets `view.isMultipleTouchEnabled = true` in `didMove(to:)` — see the control fix below. |
| `Controls/DualStickControlScheme.swift` | Adds a static "MOVE"/"FIRE" legend at the bottom of each half of the screen. |

### Map collision

Player and zombie movement now collide with wall and obstacle tiles.
Implementation is deliberately simple and consistent with how this
codebase already does movement (manual math, not SpriteKit physics
bodies) rather than introducing `SKPhysicsBody`/contact bitmasks as a new
parallel system:

- `TileMapBuilder.build` collects the world-space rect of every wall or
  obstacle tile it places into `solidRects`, alongside the visual node.
- `Geometry.swift`'s `resolveCollision` does simple axis-separated
  collision: try the full proposed move, then X-only, then Y-only, then
  give up and stay put. This lets the player/zombies **slide along** a
  wall or obstacle edge instead of just stopping dead or clipping through
  a corner.
- Both `Player.move` and `Walker.update` call it with their own radius
  (`Balance.playerRadius` / `Balance.zombieRadius`).

**Scope note**: this covers player/zombie movement only. Bullets still
pass through walls (Bullet has no notion of the map). Enemies originally
walked straight at the player and simply stopped when blocked — **Phase 8
replaced that with flow-field pathfinding**; see below.

### Making the two maps genuinely different

Beyond the different tileset (Wasteland vs. Interior, from Phase 4), each
map now has its own obstacle **arrangement**, not just different obstacle
textures scattered in the same pattern:

- **Wasteland** (`Balance.wastelandObstacleLayout`): a loose, irregular
  10-position scatter — reads like scattered wreckage/crates.
- **Interior** (`Balance.interiorObstacleLayout`): two neat, grid-aligned
  8-position rows — reads like rows of desks/lockers.

Both are still fractional positions (scale with arena size, same reasoning
as Phase 4's original layout) and still best-guess tile art — the Phase 4
"verify tile indices in Xcode" caveat applies here too.

### Control fix: dual-stick couldn't move and shoot at the same time

**Root cause found**: `UIView.isMultipleTouchEnabled` defaults to `false`,
and nothing in this codebase ever set it to `true`. That means the system
only ever tracked **one touch at a time** — holding the move stick with
one finger meant a second finger touching the fire stick never generated
a `touchesBegan` event at all, so `DualStickControlScheme` never even saw
it. It wasn't a logic bug in the control scheme itself (that code already
handled independent touches correctly); the touches just never arrived.

**Fix**: `GameScene.didMove(to:)` now sets `view.isMultipleTouchEnabled =
true`. With that one line, both joysticks can be held simultaneously,
which is all "move and shoot at the same time" required.

**On the "add a shoot button" ask**: re-reading dual-stick's existing
design — the right-side joystick already *is* a shoot button in every
sense described: pressing it fires, it aims wherever it's dragged with no
requirement that a zombie be there, and holding it fires continuously at
the equipped weapon's normal cadence rather than one shot per tap (there's
no separate "faster fire" mechanic — fire rate is fixed per weapon, per
`Balance.swift`; "hold to keep firing" was already the behavior once the
touch actually arrived). So no new control was added — the multitouch fix
was the actual missing piece. What *was* added: a static "MOVE"/"FIRE"
text legend at the bottom of each screen half (`DualStickControlScheme`),
since both joysticks float (invisible until first touch, per
`VirtualJoystick`'s design) and had no static hint telling a new player
which half does what before their first touch.

Single-stick + auto-aim mode was reviewed too — its move-only,
auto-aim/auto-fire design was working as intended (Phase 1's spec for that
mode) and only ever tracks one touch by design, so there was no
multitouch bug to fix there; it's unchanged this pass.

## Architecture — Phase 7 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Config/Balance.swift` | Adds `MapStructure` (a named multi-tile object), floor-variant tile arrays and corrected wall tiles. *(`MapStructure` and the fractional placements were removed again in Phase 8 — layouts now live in ASCII grids.)* |
| `Systems/TileMapBuilder.swift` | Rewritten to composite three layers instead of one flat floor + scattered single tiles: randomized floor variants, small single-tile scatter clutter, and named multi-tile structures stamped on top (with their own solid rects). |

### The map was "just blocks scattered everywhere" — here's what changed

Phase 4/6 built the tile system but only ever placed **one repeated single
tile** for the wall and for each scattered "obstacle" — visually flat, and
with two real mistakes: `wastelandWallTile` was pointed at a wood crate
tile (not a wall), and `interiorWallTile` was pointed at the floor's own
baseboard trim (not a wall) — both were guesses from a thumbnail that
turned out wrong once actually verified. This pass:

1. **Re-verified every tile coordinate against an annotated, labeled
   render of both sheets** (cropped and grid-labeled at each cell so every
   pick below could be checked directly, not eyeballed from a thumbnail).
   This caught and fixed both wall-tile mistakes above.
2. **Added `MapStructure`**: a named rectangular block of tiles (e.g. "4
   tiles wide, 2 tall, starting at sheet position (0,5)") stamped onto the
   map as one real recognizable object, fully solid. Every structure
   below turned out to be a clean contiguous rectangle in the sheet, so no
   per-cell shape list was needed — just an origin + size.
3. **Added floor variety**: a handful of plain/cracked floor tile variants
   picked per-cell at build time instead of one tile repeated everywhere.

### Wasteland ("The Yard") — now has actual cars and cover

- **4 vehicles** (red truck, blue truck, maroon car, black car), each a
  real 4x2-tile vehicle sprite, placed as large cover objects — directly
  answers "add the cars."
- **A crate stack** (2x2) and **a gas pump** (2x1) as smaller named cover.
- Small loose scatter (barrels, a tire, a wood crate) still fills in
  around them, at roughly half the density of Phase 6's version now that
  the named structures carry more of the visual weight.
- Wall ring uses the dark vertical-slat metal wall tile (corrected from
  the wood-crate mistake).

### Interior ("The Facility") — now reads as an actual furnished space

- **6 furniture clusters**: two wardrobe/cabinet blocks, a 3-wide row of
  vending machines (a "break room"), a pool table, a pair of beds, and a
  desk cluster — real recognizable rooms/furniture instead of one lone
  cabinet tile repeated at scattered points.
- Wall ring uses a plain grey server-rack-panel slice — this sheet has
  **no dedicated wall/brick art at all** (confirmed again this pass, same
  conclusion as Phase 4), so a neutral furniture-adjacent tile stands in;
  deliberately a *different* tile than any of the furniture clusters, so
  the border doesn't read as "part of" a nearby wardrobe.

### Scope / what's still a guess

- **Vehicles are treated as a uniform 4x2 rectangle** for simplicity, even
  though the source art's cab silhouette leaves one corner transparent on
  some of them — this just reads as a small gap in the roof corner, not a
  functional bug (transparent, not invisible-but-solid). Worth a glance in
  Xcode.
- **Structure placements are fixed fractional positions**, chosen to
  clear the 8 fixed spawn points and each other by eye, same as Phase 4/6's
  scatter positions — still not pixel-verified in a running build.
- **No pathfinding around structures** — superseded by Phase 8, which
  added a flow field so enemies route around cover properly.

## Architecture — Phase 8 (new/changed this pass)

| File | Responsibility |
|---|---|
| `Systems/MapLayouts.swift` | **New.** Hand-editable ASCII arena layouts (`.` floor, `#` wall, `X` cover, `S` spawn) + the parser that turns them into cells and spawn markers. |
| `Systems/NavGrid.swift` | **New.** Walkability grid, BFS flow field shared by every enemy, line-of-sight sampling, and the build-time connectivity flood fill. |
| `Systems/TileMapBuilder.swift` | Rewritten to render a parsed layout, emit solid rects + spawn points + a NavGrid, and scale tiles to fit the arena on screen. |
| `Systems/WaveManager.swift` | Spawn points are now validated against solid geometry, relocated by outward ring search if blocked, and loudly flagged if too few survive. |
| `Entities/Walker.swift` | Follows the flow field around obstacles; straight-line pursuit only when the player is in line of sight. |
| `Config/Balance.swift` | Map *arrangement* constants removed (they live in ASCII now); what remains is tile-art selection plus nav/spawn tuning. |

### Bug 1 — zombies spawning inside solid geometry

`spawnOne` assigned `spawnPoints.randomElement()` with no validation, so a
spawn point overlapping a wall produced a zombie that `resolveCollision`
rejected in every direction — frozen forever, and the round could never
end because it never died.

`WaveManager.configureSpawning` now takes the map's solid rects and checks
every point with a zombie-radius circle. A blocked point is **relocated**
by searching outward in rings (8 samples per ring, growing with radius)
for the nearest position that fits, rather than being silently dropped —
otherwise a map could quietly lose a whole corner and funnel every zombie
in from one side. If fewer than `Balance.minimumValidSpawnPoints` (3)
survive, it prints a warning *and* trips `assertionFailure`, so a broken
layout fails loudly in debug instead of shipping.

### Bug 2 — no pathfinding, so walls were permanent shelter

**Recompute strategy: one BFS flow field per player tile-crossing.**
Rather than 25 concurrent A* searches, `NavGrid` runs a single
breadth-first search *outward from the player's cell* across all walkable
cells, recording for each cell a unit vector pointing at the neighbour
that steps toward the player. Every zombie then reads one array entry —
the cost is independent of enemy count.

The BFS re-runs **only when the player's cell index changes**
(`updateFlowField` early-outs otherwise), so it's called every frame but
does real work perhaps a few times a second while moving, and zero times
while standing still. On these 35×15 maps a full rebuild touches ~400
cells, which is trivial.

Details worth knowing:
- **8-connected** so zombies move diagonally instead of stair-stepping,
  with corner-cutting refused: a diagonal step is only allowed if both
  adjacent orthogonal cells are also walkable, otherwise zombies clip
  through wall corners and fight the collision resolver.
- **Line of sight wins over the flow field.** Grid-derived vectors are
  axis-aligned and look robotic in the open, so when
  `hasLineOfSight(from:to:)` is clear the walker just goes straight at the
  player. The flow field only takes over when something is actually in the
  way.
- **`resolveCollision` is unchanged** and still does the last few pixels
  of sliding along edges. Flow field = routing, collision = contact.

### Map redesign

Layouts are now ASCII grids in `MapLayouts.swift`, editable by hand:

```
#....XX....XX....XX....XX....XX...#
#.................................#
#.S.............................S.#
```

Both maps were checked against every rule in the brief, and the two that
matter most are re-verified **in code at build time**:
`NavGrid.isFullyConnected()` flood-fills the walkable space and
warns + asserts if anything is sealed off, and `WaveManager` validates
every spawn point.

**Connectivity flood-fill result: both maps pass.** Offline I also
verified the stronger property that the runtime check can't cheaply cover:
from *every one* of the 401 (Wasteland) / 395 (Facility) possible player
cells, every walkable cell has a route to the player — so the
corner-cutting rule never strands anything. Longest route seen was 34
steps.

One non-obvious constraint fell out of this and is worth recording,
because it silently breaks maps: **a player/zombie collision circle is
40pt across, but a tile renders at only ~24pt** on the smallest supported
screen. So a 1-tile doorway is physically impassable even though the tile
grid happily routes enemies through it — exactly the "frozen zombie" class
of bug this phase set out to kill, in a new disguise. The Facility's
doorways are therefore **3 tiles wide**, all corridors are ≥3 tiles, and
spawn markers sit 2 cells in from the border (a marker hard against a wall
would be relocated by the validator on every single round). Both layouts
were checked by sampling the actual configuration space of a 40pt circle
and confirming it forms one connected region containing every spawn point
and the player's start.

Layout summary:
- **The Yard** (Wasteland): open arena, two staggered bands of 1–2 tile
  cover with ≥3 free tiles between clusters and from the border. 2×2
  clusters render as whole vehicles.
- **The Facility** (Interior): two pass-through rooms, each with a 3-wide
  doorway in the top *and* bottom wall — no single-entrance rooms — inside
  a ring of corridors, plus side cover in the two widest corridors.
- Both: 10 perimeter spawn points spread across all four edges, zero
  dead-end cells (no cell has fewer than two walkable neighbours), so
  there's nowhere to back into and be safe.

### `.ashyard` renamed to `.facility`

The old case name contradicted its indoor visuals. `MapID` now has a
custom `init(from:)` that still decodes `"ashyard"` — without it, every
save written by an older build would fail to load outright rather than
just showing a renamed map.

### Tile indices I'd double-check by eye

Still unverified in a running build (no Xcode here). Most suspect:
- **`interiorWallTile` (0,9)** — a server-rack panel standing in for a
  wall, because this sheet has *no* wall/brick art at all. It's the
  weakest pick in either map; if the room walls look like furniture,
  that's why.
- **`wastelandVehicleOrigins`** — the four 2×2 vehicle sprites assume each
  car occupies a clean 2×2 block starting at its listed corner. If a car
  is actually drawn 4 tiles wide, these will render as half a vehicle.
- **`wastelandWallTile` (6,6)** — a middle slice of taller fence art, so
  it may not tile seamlessly top-to-bottom along the border.
- Floor variants for both maps are the safest picks (plain ground only,
  with the road strip and baseboard trim deliberately excluded).

## First-person conversion (`fps-raycaster` branch)

| File | Responsibility |
|---|---|
| `Config/RaycasterConfig.swift` | **New.** All presentation tuning (cell size, FOV, shading, look sensitivity range, viewmodel size) + the `RenderQuality` enum. Deliberately *not* in Balance.swift — Balance owns gameplay numbers, which carried over untouched. |
| `Systems/MapModel.swift` | **New.** Turns the same ASCII layout into world geometry, solid rects, spawn points and a NavGrid, and says which tile art textures each wall. Also runs the connectivity flood-fill that used to live in TileMapBuilder. |
| `Raycaster/WallTextureCache.swift` | **New.** Pre-slices each wall tile into 32 vertical 1px strips once at load. |
| `Raycaster/RaycastRenderer.swift` | **New.** CPU DDA raycast, pooled column sprites, depth buffer, distance/side shading, flat floor+ceiling planes. |
| `Raycaster/BillboardRenderer.swift` | **New.** Projects world sprites to screen, sorts far-to-near, slices each into vertical strips and depth-tests every strip against the wall depth buffer. |
| `Raycaster/WeaponViewModel.swift` | **New.** Bottom-of-screen gun — **placeholder art, see the warning below.** |
| `Controls/FPSControls.swift` | **New.** Move stick + drag-to-look + fire/reload/swap. Replaces both old schemes. |
| `Systems/HitscanResolver.swift` | **New.** Ray-vs-enemy-circle, clipped by the first wall along the ray. |
| `Scenes/GameScene.swift` | Rewritten, but keeps the exact public API (`player`, `economyManager`, `gameState`, `configureNewRun`, `configureRestoring`, `refreshControlSchemeIfNeeded`) that Shop/Pause/Settings/MapSelect/LoadGame call — which is why none of those needed editing. |
| `Entities/Player.swift` | Now a camera (position + facing angle) plus the unchanged inventory/perk/health API ShopScene talks to. No longer an SKNode — the player is never drawn. |
| `Entities/Walker.swift` | Same states, same flow-field pathfinding. Animation is now advanced manually per frame instead of by SKActions (the node is never in the scene graph; the renderer just asks for `currentTexture`), and textures are cached per variant instead of re-decoded on every spawn. |
| `Entities/Bullet.swift`, `CoinPickup.swift` | Plain world-space entities drawn as billboards. |

Deleted: `DualStickControlScheme`, `SingleStickAutoAimControlScheme`,
`TileMapBuilder`. `ControlScheme.swift` is reduced to just the
`ControlSchemeType` enum, kept only because GameState and SettingsStore
persist it — removing it would break existing saves for no benefit.
`NavGrid.swift` and `MapLayouts.swift` are **functionally unchanged**
(comment-only edits).

### The renderer

Standard DDA in grid space, where a cell is exactly 1 unit so stepping is
two additions and no division. Per column: cast, take the **perpendicular**
wall distance (this *is* the fisheye correction — algebraically identical to
multiplying euclidean distance by `cos(rayAngle - playerAngle)`, minus the
per-column trig), compute `height = screenHeight / distance`, and assign a
cached 1px texture strip to a pooled sprite.

Nothing is allocated per frame: column nodes are pooled and rebuilt only
when the resolution setting changes, texture strips are `SKTexture(rect:in:)`
references made once at load (no pixel copying), and the DDA writes into
preallocated scratch arrays.

Shading is `colorBlendFactor` toward black, ramped with distance, plus a
flat extra darkening on north/south wall faces so corners stay readable
without any lighting. Floor and ceiling are two flat colour planes —
textured floorcasting is per-pixel work that a SpriteKit node-per-column
approach can't do cheaply, so it's deliberately skipped.

### Column count

`RenderQuality` in **Settings → Graphics → Resolution**:

| Setting | Columns | Billboard slices |
|---|---|---|
| Low | 160 | 6 |
| Medium (default) | 240 | 10 |
| High | 320 | 14 |

Clamped so a column is never narrower than one point. **Frame time is not
measured here** — this environment has no Xcode, simulator or device, so no
number in this repo is a real measurement. A DEBUG-only on-screen readout
(ms / fps / column count / node count) is wired into GameScene so the dial
can be tuned against a real reading on device.

### Billboard depth clipping

A single SKSpriteNode can't be partially occluded, so each billboard is cut
into vertical slices (6–14 by quality) and **every slice is depth-tested
against the wall depth buffer column it lands on**. A zombie half behind a
corner loses exactly the slices the wall covers. The logic is written and
reviewed but **not visually confirmed** — see "what still needs verifying".

### Hitscan vs projectiles

Split on each weapon's existing `bulletBehavior`, so no weapon stats changed:

- **`.standard` → hitscan.** Pistol, SMG, assault rifle, sniper, LMG. An
  enemy only counts if it's nearer than the first wall along the ray.
- **Shotgun** is the same path with `pelletCount` 8 — eight hitscans with
  the weapon's existing `spreadAngle`, damage split per pellet exactly as
  before.
- **`.aoe` / `.chain` → real projectiles.** Grenade launcher and Arc Cannon
  still travel through the world, because their travel time *is* the
  mechanic. They now also stop on walls.

### ⚠️ Weapon viewmodel is placeholder art, and it will look wrong

The pack's weapon sheets (`Pistol_Shoot`, `Rifle_Shoot`, …) are small
top-down/side-on **pickup** sprites, not first-person hand-and-gun
viewmodels. Pinned to the bottom of the screen they read as a floating
side-view gun, not a weapon the player is holding. It's wired up anyway so
firing has visual feedback and the plumbing is ready, but this is a genuine
art mismatch, not something that just needs positioning tweaks — it needs
purpose-drawn FPS viewmodel art.

### Controls

Left half: floating stick, Y = forward/back, X = strafe, both relative to
facing. Right half: drag to turn. **No vertical look** — a raycaster has no
true pitch, and the screen-offset fake looks bad enough that skipping it was
the better call (the plumbing for a horizon offset exists in
`RaycastCamera.pitchOffset` if you want to try). Fire (hold to keep firing),
reload and swap buttons sit bottom-right. Look sensitivity is a slider in
**Settings → Controls**.

### What's stubbed or deliberately skipped

- **Textured floors/ceilings** — flat colours only (see above).
- **No vertical look** (see above).
- **Impact/explosion effects aren't drawn.** The effects sheets are loaded
  for the projectile billboard but hitscan hits and AoE blasts have no
  visual — the top-down build's ring/line flourishes were 2D-world nodes
  and don't survive the conversion. Damage still applies correctly.
- **Enemies have no directional sprites**, so billboards always face the
  camera. That's how Doom-era games with a single view angle worked; faking
  rotation from a front-facing sheet would look worse.
- **No sprite-vs-sprite occlusion ordering beyond depth sort** — two
  overlapping zombies sort by distance, which is correct, but neither is
  clipped against the other.

### What still needs verifying on a device

None of the below could be checked here — no Apple toolchain in this
environment, so this is careful review only, not a running build:

1. **Frame time with 25 concurrent zombies**, and whether Medium (240
   columns) holds 60fps on a mid-range device or needs to drop to Low.
2. **Billboard depth clipping** actually looking right at wall edges —
   the maths is right on paper but slice-vs-column alignment is exactly
   the kind of thing that's off by one in practice.
3. **Wall texture orientation** — whether the strip-mirroring on the two
   "back" faces makes texture detail read correctly as you walk around a
   block, or looks flipped.
4. **Whether `interiorWallTile` reads as a wall at all** in first person.
   It's a server-rack panel standing in for a wall (this sheet has no wall
   art) and it was already the weakest tile pick in the top-down build —
   at full screen height it may look obviously wrong.

## Power-up / pickups pass (`fps-raycaster`)

### Difficulty actually changes the fight now

The root cause of "Easy still feels hard": `difficultyEasyMultiplier` only
scaled zombie **health and contact damage**. Same horde, same pace, just
fewer bullets each. Two new multipliers fix the actual pressure, applied in
`WaveManager` (wave size in `startNextRound`, cadence via
`effectiveSpawnInterval`) rather than on the Walker:

| | health/damage | spawn count | spawn interval | R1 | R5 | R10 | gap |
|---|---|---|---|---|---|---|---|
| Easy | 0.75x | **0.70x** | **1.30x** (slower) | 4 | 13 | 23 | 0.78s |
| Medium | 1.00x | 1.00x | 1.00x | 6 | 18 | 33 | 0.60s |
| Hard | 1.35x | **1.25x** | **0.80x** (faster) | 8 | 22 | 41 | 0.48s |

### Player baseline + weapon rebalance

Max health 100 -> **150**, move speed 220 -> **250**, pistol damage
34 -> **42**. Every other weapon scaled **x1.2**; fire rates, magazines and
ranges untouched, so DPS ordering is preserved exactly.

| Weapon | Damage | DPS before | DPS after |
|---|---|---|---|
| Pistol | 34 -> **42** (+23.5%) | 154.5 | 190.9 |
| SMG | 16 -> **19.2** | 177.8 | 213.3 |
| Shotgun | 140 -> **168** | 186.7 | 224.0 |
| Assault Rifle | 30 -> **36** | 250.0 | 300.0 |
| Sniper | 220 -> **264** | 244.4 | 293.3 |
| LMG | 26 -> **31.2** | 325.0 | 390.0 |
| Grenade Launcher | 180 -> **216** | 163.6 | 196.4 |
| Arc Cannon | 60 -> **72** | 120.0 | 144.0 |

### Coins

Base 25 -> **34**, per-round 5 -> **7** (both +35%). New flat **wave-clear
bonus** of `50 + 15 x (round-1)`, paid the moment the last zombie dies —
about a quarter of round-1 income, fading to a rounding error later so it
never becomes the main earner.

### World pickups

Physical items spawned on walkable floor tiles (via `MapModel`/the layout
grid, never inside geometry), collected by walking over them, drawn as
billboards like everything else. Icons are existing Items_Sprites_16x16 art.

| Pickup | Icon | Effect |
|---|---|---|
| Medkit | medkit | Heals 40% of **current** max health, so it scales with Vitality |
| Double Damage | grenades | All weapon damage x2 for 15s |
| Speed Boost | battery | Move speed x1.6 for 12s |
| Nuke | skull | Kills every living zombie; each still drops its normal coins |

- **The medkit is guaranteed once per round**, scheduled 8-18s in rather
  than sitting on the floor from second zero — there is otherwise no way to
  heal mid-round at all.
- Non-medkit pickups roll every 20-30s while zombies are alive, weighted
  46/46/8 — at roughly three rolls per round that lands **about one nuke
  every four rounds**.
- Pickups despawn after 20s, blinking for the last 5s as a warning.
- Double Damage is applied at fire time in `GameScene`, not on the Weapon,
  so the weapon classes and their stats stay untouched.

### Polish-pass verification

All five checked by running them, not by inspection alone:

1. **Billboard depth clipping — PASS.** Re-ran the projection + DDA maths as
   it stands now: 467 genuine partial-occlusion configurations found (a
   zombie at a wall edge losing 3/10, 5/10, 8/10 slices), fully-visible /
   fully-hidden / behind-camera cases all correct, and a 3,294-projection
   sweep found **zero** cases of a sprite drawing through a wall.
2. **Pause — PASS.** Every gameplay timer runs off `gameClock`; no
   wall-clock API appears anywhere in the gameplay path. The `isPaused`
   guard runs *before* `gameClock` advances and `lastUpdateTime` is updated
   *before* the guard, so the paused span is never folded into the next
   delta. Buffs store an absolute gameClock deadline, not a countdown.
3. **Difficulty — PASS.** Captured once at configure time, `WaveManager
   .difficulty` written exactly once, no mid-run write path, read-only in
   Settings mid-run — and it now visibly changes wave size and cadence
   (table above).
4. **Save/load — PASS.** Buffs are absent from `GameState` entirely *and*
   explicitly cleared on load. Coins/weapons/overclock tiers round-trip.
   Weapon damage isn't persisted at all (only type + tier), so old saves
   automatically pick up the rebalanced numbers. `restoreHealth` clamps to
   the new max, so a pre-buff save loads at 100/150 rather than overflowing.
5. **HUD — PASS after a fix.** The check found a real collision, though not
   from the new buff pills: the DEBUG frame-time label was overlapping the
   perk icon row. Moved it to the bottom-left. Re-run gives **0 overlaps**
   across all 13 HUD elements on iPhone SE / 13 mini / 15 / 15 Pro Max.

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
- **One enemy type**, **single-screen arena**, **manual circle-vs-circle
  collision** — unchanged from Phase 1. (Straight-line pursuit was
  replaced by flow-field pathfinding in Phase 8.)
- **Chain (Arc Cannon) and AoE (Grenade Launcher) visuals** are minimal
  placeholder flourishes (a fading ring / a fading line) — functional, not
  polished.
- **Shop and Settings layouts are fixed, non-scrolling grids** — comfortable
  on iPad landscape, tight on smaller iPhones. A scrollable list would be
  the natural follow-up for both; out of scope for this pass.
- **Effects sprites (bullet impact, explosion, pop-ups) are measured and
  have Balance.swift frame constants, but aren't wired to any gameplay
  event** — the Phase 4 brief listed them as part of the delivered pack but
  didn't ask for them to be triggered on hit/explosion/pickup, so they
  aren't yet. The AoE explosion and chain-lightning arc still use their
  Phase 2 placeholder shapes (a fading ring / a fading line).
- **Tile indices are an unverified best guess** — see the Phase 4 section
  above for specifics on what to check in Xcode.
- **Bullets pass through walls/obstacles** — Phase 6 added collision for
  player/zombie movement only (what was asked for); bullet-vs-wall
  collision would be a separate, bigger change (Bullet has no concept of
  the map today) and wasn't part of this pass.
- **Bullets pass through walls** — collision covers entity movement only;
  Bullet has no notion of the map. Unchanged in Phase 8.
- Not compiled with `xcodebuild`/Xcode in this environment (Linux, no
  Apple toolchain) — reviewed carefully by hand (including catching and
  fixing two real bugs along the way: the `didMove(to:)` re-presentation
  issue and a Walker animation state that could get permanently stuck if
  only some frame sequences were missing), but give it a first real build
  in Xcode before relying on it.
