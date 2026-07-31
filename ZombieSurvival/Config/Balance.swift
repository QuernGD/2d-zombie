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
}
