import CoreGraphics
import Foundation

/// Single source of truth for every tuning number in the game.
/// Nothing gameplay-related should be hardcoded outside this file —
/// designers should be able to rebalance the whole game from here.
enum Balance {

    // MARK: - Player

    static let playerMaxHealth: CGFloat = 100
    static let playerMoveSpeed: CGFloat = 220 // points per second
    static let playerRadius: CGFloat = 20

    // MARK: - Pistol (starting weapon)

    static let pistolDamage: CGFloat = 34
    static let pistolMagazineSize: Int = 12
    static let pistolFireRate: TimeInterval = 0.22 // seconds between shots
    static let pistolReloadTime: TimeInterval = 1.4
    static let pistolBulletSpeed: CGFloat = 900 // points per second
    static let pistolBulletRange: CGFloat = 700 // points before a bullet despawns
    static let pistolBulletRadius: CGFloat = 4

    // MARK: - Zombie (Walker)

    static let zombieBaseHealth: CGFloat = 150
    static let zombieHealthPerRoundLinear: CGFloat = 100
    /// Rounds 1...zombieLinearCapRound scale linearly; after that, compounding kicks in.
    static let zombieLinearCapRound = 9
    static let zombieHealthCompoundMultiplier: CGFloat = 1.1
    static let zombieMoveSpeed: CGFloat = 70
    static let zombieContactDamage: CGFloat = 10
    static let zombieAttackCooldown: TimeInterval = 1.0
    static let zombieRadius: CGFloat = 18

    /// 150 base, +100 each round through round 9, then x1.1 compounding after.
    static func zombieHealth(forRound round: Int) -> CGFloat {
        guard round > 1 else { return zombieBaseHealth }
        if round <= zombieLinearCapRound {
            return zombieBaseHealth + CGFloat(round - 1) * zombieHealthPerRoundLinear
        }
        let healthAtCap = zombieBaseHealth + CGFloat(zombieLinearCapRound - 1) * zombieHealthPerRoundLinear
        let roundsPastCap = round - zombieLinearCapRound
        return healthAtCap * pow(zombieHealthCompoundMultiplier, CGFloat(roundsPastCap))
    }

    // MARK: - Spawning

    /// Hard cap on simultaneously-alive enemies; the rest wait in WaveManager's spawn queue.
    static let maxConcurrentEnemies = 25
    static let spawnInterval: TimeInterval = 0.6

    /// Total enemies queued for a given round. Scales with round number.
    static func enemyCount(forRound round: Int) -> Int {
        return 6 + (round - 1) * 3
    }

    // MARK: - Controls

    static let joystickRadius: CGFloat = 60
    static let joystickKnobRadius: CGFloat = 27

    // MARK: - Pause safety

    /// Upper bound on a single frame's deltaTime. Without this, resuming
    /// from a paused shop (or any frame hitch) would hand every timer-driven
    /// system one giant catch-up tick — this makes that impossible.
    static let maxDeltaTime: TimeInterval = 0.05

    // MARK: - Coins

    static let coinBaseValue: Int = 25
    static let coinPerRound: Int = 5
    static let coinMagnetRadius: CGFloat = 60
    static let coinCollectRadius: CGFloat = 26
    static let coinMagnetSpeed: CGFloat = 260
    static let coinRoundEndFlyDuration: TimeInterval = 0.35

    /// 25 base, +5 per round.
    static func coinValue(forRound round: Int) -> Int {
        coinBaseValue + coinPerRound * max(0, round - 1)
    }

    // MARK: - Weapon costs (Pistol is free/starting, defined on WeaponType.pistol)

    static let smgCost = 750
    static let shotgunCost = 1200
    static let assaultRifleCost = 1500
    static let sniperCost = 2000
    static let lmgCost = 2500
    static let grenadeLauncherCost = 3000
    static let arcCannonCost = 5000

    // MARK: - Weapon stats
    // baseDamage is the "per shot" potential; pellet weapons split it across
    // pelletCount so a full-connect blast totals roughly baseDamage.
    // All placeholder numbers — tune freely, nothing else depends on these values.

    static let smgDamage: CGFloat = 16
    static let smgMagazineSize = 30
    static let smgFireRate: TimeInterval = 0.09
    static let smgReloadTime: TimeInterval = 1.6
    static let smgBulletSpeed: CGFloat = 950
    static let smgRange: CGFloat = 650

    static let shotgunDamage: CGFloat = 140
    static let shotgunPelletCount = 8
    static let shotgunSpreadAngle: CGFloat = .pi / 7 // ~25.7 degrees, full cone
    static let shotgunMagazineSize = 6
    static let shotgunFireRate: TimeInterval = 0.75
    static let shotgunReloadTime: TimeInterval = 2.0
    static let shotgunBulletSpeed: CGFloat = 850
    static let shotgunRange: CGFloat = 350

    static let assaultRifleDamage: CGFloat = 30
    static let assaultRifleMagazineSize = 25
    static let assaultRifleFireRate: TimeInterval = 0.12
    static let assaultRifleReloadTime: TimeInterval = 1.8
    static let assaultRifleBulletSpeed: CGFloat = 1000
    static let assaultRifleRange: CGFloat = 750

    static let sniperDamage: CGFloat = 220
    static let sniperMagazineSize = 5
    static let sniperFireRate: TimeInterval = 0.9
    static let sniperReloadTime: TimeInterval = 2.2
    static let sniperBulletSpeed: CGFloat = 1400
    static let sniperRange: CGFloat = 1200

    static let lmgDamage: CGFloat = 26
    static let lmgMagazineSize = 60
    static let lmgFireRate: TimeInterval = 0.08
    static let lmgReloadTime: TimeInterval = 3.2
    static let lmgBulletSpeed: CGFloat = 950
    static let lmgRange: CGFloat = 700

    static let grenadeLauncherDamage: CGFloat = 180
    static let grenadeLauncherAoeRadius: CGFloat = 90
    static let grenadeLauncherMagazineSize = 4
    static let grenadeLauncherFireRate: TimeInterval = 1.1
    static let grenadeLauncherReloadTime: TimeInterval = 2.4
    static let grenadeLauncherBulletSpeed: CGFloat = 600
    static let grenadeLauncherRange: CGFloat = 500

    static let arcCannonDamage: CGFloat = 60
    static let arcCannonChainMaxJumps = 4
    static let arcCannonChainRange: CGFloat = 150
    static let arcCannonChainFalloff: CGFloat = 0.65
    static let arcCannonMagazineSize = 8
    static let arcCannonFireRate: TimeInterval = 0.5
    static let arcCannonReloadTime: TimeInterval = 2.0
    static let arcCannonBulletSpeed: CGFloat = 1000
    static let arcCannonRange: CGFloat = 600

    // MARK: - Overclock Station (applies to the equipped weapon only)

    static let overclockTier1Cost = 5000
    static let overclockTier1DamageMultiplier: CGFloat = 2.0
    static let overclockTier2Cost = 12500
    static let overclockTier2DamageMultiplier: CGFloat = 3.5
    static let overclockTier2FireRateMultiplier: CGFloat = 1.25

    // MARK: - Shop misc

    static let mysteryCrateCost = 950
    static let ammoRefillCost = 500
    /// Mystery Crate weighting: owned weapons are still possible rolls, just rarer.
    static let ownedWeaponCrateWeight: CGFloat = 1.0
    static let unownedWeaponCrateWeight: CGFloat = 5.0

    // MARK: - Perks (2,500 each, one-time purchase, persist for the run)

    static let perkCost = 2500
    static let vitalityMaxHealthMultiplier: CGFloat = 2.0
    static let rapidHandsReloadMultiplier: CGFloat = 0.5
    static let overdriveFireRateMultiplier: CGFloat = 1.25
    static let sprinterMoveSpeedMultiplier: CGFloat = 1.2

    // MARK: - Zombie animation (frame timing; frame source files documented in Assets/README.md)

    static let zombieIdleFrameTime: TimeInterval = 0.09
    static let zombieMoveFrameTime: TimeInterval = 0.07
    static let zombieAttackFrameTime: TimeInterval = 0.06
    static let zombieDeathEffectDuration: TimeInterval = 0.25

    // MARK: - Difficulty (global multiplier on zombie health + contact damage)

    static let difficultyEasyMultiplier: CGFloat = 0.75
    static let difficultyMediumMultiplier: CGFloat = 1.0
    static let difficultyHardMultiplier: CGFloat = 1.35

    // MARK: - Settings UI

    /// Volume controls are stepped (0/20/40/60/80/100%), not a continuous
    /// drag slider — SpriteKit has no built-in slider widget and a real
    /// drag-tracked one was more UI than this pass justified.
    static let volumeSliderSteps = 5

    // MARK: - Phase 4: Character spritesheets (Zombie1-4 + Player)
    // All measured directly from the delivered art (192x32/256x32/96x32/
    // 192x32/256x32 strips of 32x32 frames) — these exactly match the frame
    // counts stated in the brief, unlike several sheets below.

    static let characterFrameSize: CGFloat = 32
    static let characterIdleFrameCount = 6
    static let characterRunFrameCount = 8
    static let characterHitFrameCount = 3
    static let characterKnockedFrameCount = 6
    static let characterDeathFrameCount = 8

    static let characterIdleFrameTime: TimeInterval = 0.12
    static let characterRunFrameTime: TimeInterval = 0.08
    static let characterHitFrameTime: TimeInterval = 0.07
    static let characterKnockedFrameTime: TimeInterval = 0.09
    static let characterDeathFrameTime: TimeInterval = 0.08

    /// No zombie "attack" sheet exists in this art pack, so Hit/Knocked are
    /// repurposed as light/heavy damage-*reaction* flinches instead: a
    /// single hit dealing at least this much damage plays Knocked, anything
    /// under it plays Hit.
    static let zombieKnockedDamageThreshold: CGFloat = 50

    // MARK: - Phase 4: Weapon shoot spritesheets
    // 8 WeaponTypes share 6 unique sheets (no dedicated SMG or Arc Cannon
    // art) — see WeaponType.shootSheet in WeaponInventory.swift for the
    // mapping. Frame counts are measured (vary 4-13, matching the brief's
    // "varies 4-13" claim).

    static let weaponFrameSize: CGFloat = 32
    static let weaponShootFrameTime: TimeInterval = 0.045
    static let pistolShootFrameCount = 5
    static let smgShootFrameCount = 9          // reuses Revlover_Shoot.png (no dedicated SMG sheet)
    static let shotgunShootFrameCount = 10     // Pump_Shoot.png
    static let assaultRifleShootFrameCount = 4 // Rifle_Shoot.png
    static let lmgShootFrameCount = 4          // reuses Rifle_Shoot.png (long-gun family)
    static let sniperShootFrameCount = 13
    static let arcCannonShootFrameCount = 13   // reuses Sniper_Shoot.png (precision/beam motif)
    static let grenadeLauncherShootFrameCount = 12 // RocketLauncher_Shoot.png

    // MARK: - Phase 4: Effects spritesheets
    // The brief states bullet impact=3f, explosion=10f, pop-ups=3f each, but
    // the delivered files measure 100x20 (bullet impact/pop-ups, 20x20
    // frames) and 336x48 (explosion, 48x48 frames) — 5 and 7 frames
    // respectively. Using the measured values.

    static let bulletImpactFrameSize: CGFloat = 20
    static let bulletImpactFrameCount = 5
    static let explosionFrameSize: CGFloat = 48
    static let explosionFrameCount = 7
    static let popupFrameSize: CGFloat = 20
    static let popupFrameCount = 5
    static let effectFrameTime: TimeInterval = 0.05

    // MARK: - Phase 4: Item spritesheets (16x16)
    // The brief states 3 frames each; the delivered sheets measure 112x16 at
    // 16x16 frames — 7 frames. Using the measured value.

    static let itemFrameSize: CGFloat = 16
    static let itemFrameCount = 7
    static let itemFrameTime: TimeInterval = 0.15

    // MARK: - Phase 4: Tile-based arenas
    // Neither tileset ships with a documented tile-index legend, so these
    // column/row picks are a best-effort visual guess made by eyeballing the
    // sheets — flag for manual verification/adjustment in Xcode, not exact.

    static let tileSize: Int = 32

    static let wastelandFloorTile = TileCoord(column: 0, row: 1)
    static let wastelandWallTile = TileCoord(column: 6, row: 14)
    static let wastelandObstacleTiles: [TileCoord] = [
        TileCoord(column: 4, row: 5), TileCoord(column: 5, row: 4), TileCoord(column: 5, row: 6)
    ]

    static let interiorFloorTile = TileCoord(column: 0, row: 1)
    static let interiorWallTile = TileCoord(column: 0, row: 5) // no distinct brick tile in this sheet; a locker/cabinet tile stands in as a wall
    static let interiorObstacleTiles: [TileCoord] = [
        TileCoord(column: 6, row: 8), TileCoord(column: 6, row: 5), TileCoord(column: 2, row: 9)
    ]

    // MARK: - Phase 4: UI panels & health bar art

    /// panel1/panel2.png are 96x96, a clean 3x3 grid of 32px cells — see
    /// AssetProvider.makeResizablePanel's default centerRect (1/3,1/3,1/3,1/3).
    static let uiPanelSheetSize: CGFloat = 96
    /// health_bar_fillers.png is 4 solid 64x64 color swatches in a row,
    /// left to right: red/maroon, blue, orange/brown, green.
    static let healthBarFillerSwatchSize: CGFloat = 64
    static let healthBarFillerSwatchCount = 4
}

/// A single cell address (column, row) into a grid-based tilesheet. Plain
/// (Int, Int) tuples work but their labels don't survive assignment through
/// differently-typed call sites cleanly, so this is used everywhere a tile
/// coordinate is passed around instead.
struct TileCoord {
    let column: Int
    let row: Int
}
