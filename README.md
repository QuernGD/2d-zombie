# 2D Zombie Survival (iOS)

A top-down, twin-stick zombie survival shooter built with SpriteKit for
iOS 17+. Phase 1 was the core loop (move/aim/shoot/survive rounds/die).
Phase 2 (this pass) adds the economy: coins, a round-end shop, 8 weapons,
overclocking, perks, and animated zombie sprites — wired to auto-activate
once real art is dropped in.

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
3. Run. The game is landscape-only.
   - **Left half of the screen**: virtual joystick, moves the player.
   - **Right half of the screen**: virtual joystick, aims and fires the
     active weapon continuously while held.
4. Tap **Next Round** to start (every round, including the first — no
   auto-advance). **Shop** appears alongside it at every round break.
5. In the shop: buy weapons, a Mystery Crate, an ammo refill, an Overclock
   upgrade for your equipped weapon, or a perk. **Close** returns to the
   game exactly as you left it — same position, health, ammo, round state.

## Architecture — Phase 1 (unchanged)

| File | Responsibility |
|---|---|
| `Config/Balance.swift` | Every tuning number. Rebalance the whole game from this one file. |
| `State/GameState.swift` | Serializable (`Codable`) snapshot of a run, SpriteKit-free — ready for a future save system. |
| `Controls/*.swift` | `ControlScheme` abstraction (dual-stick active, single-stick+auto-aim built but not exposed via any settings UI yet). |
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

## Balance as implemented (Phase 1, unchanged)

- Zombie health: 150 base, +100 per round through round 9 (round 9 = 950),
  then ×1.1 compounding each round after.
- Enemy count per round: `6 + (round - 1) * 3`.
- Max concurrent alive enemies: 25.
- Pistol: 12-round magazine, 0.22s between shots, 1.4s reload.

All Phase 2 weapon/coin/overclock/perk numbers are placeholders in
`Balance.swift` — tune freely, nothing else depends on the exact values.

## What's stubbed / simplified

- **Save/load**: still Phase 3. `GameState` now also carries coins, owned
  weapons, overclock tiers, active slot, and owned perks, and stays
  `Codable`/SpriteKit-free, but nothing reads or writes it to disk yet.
  `GameScene.syncGameState()` is the integration point once it exists.
- **Game over buttons**: "Restart" reloads a fresh `GameScene` (coins,
  weapons, and perks do **not** carry over into a new run — there's no
  meta-progression system specified yet). "Main Menu" is still a no-op.
- **Single-stick + auto-aim control scheme**: still fully functional, still
  not reachable without a settings screen.
- **One enemy type**, **straight-line pursuit**, **single-screen arena**,
  **manual circle-vs-circle collision** — all unchanged from Phase 1, see
  prior notes; none of this pass touched them.
- **Chain (Arc Cannon) and AoE (Grenade Launcher) visuals** are minimal
  placeholder flourishes (a fading ring / a fading line) — functional, not
  polished.
- Not compiled with `xcodebuild`/Xcode in this environment (Linux, no
  Apple toolchain) — reviewed carefully by hand (including catching and
  fixing the `didMove(to:)` re-presentation bug above), but give it a
  first real build in Xcode before relying on it.
