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

    /// Spawn points that have been checked against the map's solid
    /// geometry. Spawning into a wall used to wedge a zombie permanently:
    /// collision resolution would reject every direction it tried, so it
    /// stood still forever and the round could never end.
    private var validatedSpawnPoints: [CGPoint] = []
    private var solidRects: [CGRect] = []

    var aliveCount: Int { aliveEnemies.count }
    var spawnPointCount: Int { validatedSpawnPoints.count }

    /// Supplies the map's spawn points and solid geometry. Every point is
    /// verified to be clear of solid tiles; one that isn't gets nudged to
    /// the nearest free spot rather than silently dropped, so a map never
    /// quietly loses a spawn corner and starts funnelling every zombie in
    /// from one side.
    func configureSpawning(spawnPoints: [CGPoint], solidRects: [CGRect], bounds: CGRect) {
        self.solidRects = solidRects
        let radius = Balance.zombieRadius

        validatedSpawnPoints = spawnPoints.compactMap { point in
            if !circleIntersectsAnyRect(center: point, radius: radius, rects: solidRects) {
                return point
            }
            if let relocated = nearestFreePosition(near: point, radius: radius, bounds: bounds) {
                print("ℹ️ Spawn point \(point) was inside solid geometry; relocated to \(relocated).")
                return relocated
            }
            print("⚠️ Spawn point \(point) is inside solid geometry and no free spot was found nearby — dropping it.")
            return nil
        }

        if validatedSpawnPoints.count < Balance.minimumValidSpawnPoints {
            let message = """
                Only \(validatedSpawnPoints.count) valid spawn point(s) survived collision filtering \
                (need at least \(Balance.minimumValidSpawnPoints)). The map layout is broken — \
                spawn markers are buried in walls or obstacles. Check MapLayouts.swift.
                """
            print("⚠️ \(message)")
            assertionFailure(message)
        }
    }

    /// Rings outward looking for a position where a zombie-sized circle
    /// fits. Sample count grows with the ring so coverage stays even as
    /// the circumference grows.
    private func nearestFreePosition(near point: CGPoint, radius: CGFloat, bounds: CGRect) -> CGPoint? {
        for ring in 1...Balance.spawnSearchMaxRings {
            let distance = CGFloat(ring) * Balance.spawnSearchRingStep
            let sampleCount = ring * 8
            for sample in 0..<sampleCount {
                let angle = (CGFloat(sample) / CGFloat(sampleCount)) * 2 * .pi
                let candidate = CGPoint(x: point.x + cos(angle) * distance, y: point.y + sin(angle) * distance)
                guard bounds.insetBy(dx: radius, dy: radius).contains(candidate) else { continue }
                if !circleIntersectsAnyRect(center: candidate, radius: radius, rects: solidRects) {
                    return candidate
                }
            }
        }
        return nil
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
        guard let spawnPoint = validatedSpawnPoints.randomElement() else { return }

        let health = Balance.zombieHealth(forRound: currentRound) * difficulty.multiplier
        let contactDamage = Balance.zombieContactDamage * difficulty.multiplier
        let walker = Walker(health: health, contactDamage: contactDamage, zombieVariant: Int.random(in: 1...4))
        walker.position = spawnPoint

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
