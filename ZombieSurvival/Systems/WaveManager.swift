import Foundation
import CoreGraphics

protocol WaveManagerDelegate: AnyObject {
    func waveManager(_ manager: WaveManager, didSpawn enemy: Enemy)
    func waveManagerRoundDidComplete(_ manager: WaveManager, round: Int)
}

/// Owns round progression and spawning. Enemies for a round are queued up
/// front; only Balance.maxConcurrentEnemies are ever alive at once, and the
/// queue refills a slot as soon as an enemy dies. The round only ends (and
/// only then does GameScene get told to show "Next Round") once the queue
/// is empty and every spawned enemy is dead. Advancing rounds is always an
/// explicit call from the player tapping "Next Round" — never automatic.
final class WaveManager {
    weak var delegate: WaveManagerDelegate?

    private(set) var currentRound: Int = 0
    private(set) var isRoundActive: Bool = false
    /// Global multiplier on spawned zombies' health and contact damage.
    /// Set once at scene setup (fresh run or restored save) and never
    /// changed mid-run — difficulty is locked for the run's duration.
    var difficulty: Difficulty = .medium

    private var pendingSpawnCount: Int = 0
    private var aliveEnemies: Set<ObjectIdentifier> = []
    private var lastSpawnTime: TimeInterval = 0
    private let spawnPoints: [CGPoint]

    var aliveCount: Int { aliveEnemies.count }

    init(spawnPoints: [CGPoint]) {
        self.spawnPoints = spawnPoints
    }

    func startNextRound() {
        guard !isRoundActive else { return }
        currentRound += 1
        pendingSpawnCount = Balance.enemyCount(forRound: currentRound)
        isRoundActive = true
    }

    /// Load-time restoration only. Sets currentRound so that the *next*
    /// startNextRound() call lands exactly on the saved round — loading a
    /// save resumes you at the round you saved during (fought fresh, since
    /// no enemies/mid-combat state is ever restored), not the round after.
    func restoreRound(_ round: Int) {
        currentRound = max(0, round - 1)
    }

    func registerDeath(of enemy: Enemy) {
        aliveEnemies.remove(ObjectIdentifier(enemy.node))
        checkRoundCompletion()
    }

    func update(currentTime: TimeInterval) {
        guard isRoundActive else { return }
        guard pendingSpawnCount > 0 else {
            checkRoundCompletion()
            return
        }
        guard aliveEnemies.count < Balance.maxConcurrentEnemies else { return }
        guard currentTime - lastSpawnTime >= Balance.spawnInterval else { return }
        spawnOne(currentTime: currentTime)
    }

    private func spawnOne(currentTime: TimeInterval) {
        let health = Balance.zombieHealth(forRound: currentRound) * difficulty.multiplier
        let contactDamage = Balance.zombieContactDamage * difficulty.multiplier
        let walker = Walker(health: health, contactDamage: contactDamage)
        walker.position = spawnPoints.randomElement() ?? .zero

        aliveEnemies.insert(ObjectIdentifier(walker.node))
        pendingSpawnCount -= 1
        lastSpawnTime = currentTime
        delegate?.waveManager(self, didSpawn: walker)
    }

    private func checkRoundCompletion() {
        guard isRoundActive, pendingSpawnCount == 0, aliveEnemies.isEmpty else { return }
        isRoundActive = false
        delegate?.waveManagerRoundDidComplete(self, round: currentRound)
    }
}
