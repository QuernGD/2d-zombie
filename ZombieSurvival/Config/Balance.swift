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
}
