import CoreGraphics
import Foundation

/// Decides *when* and *where* pickups appear, and tracks which timed buffs
/// are currently running.
///
/// Every deadline in here is stored as an absolute `gameClock` value, never
/// wall-clock time and never a countdown decremented by real seconds. That
/// single choice is what makes pause correctness fall out for free: the
/// scene's gameClock stops advancing while the shop, pause menu or settings
/// are open, so a buff with 6 seconds left still has exactly 6 seconds left
/// when you come back. It's the same fix Phase 2/3 had to make for weapon
/// fire/reload timers.
final class PickupDirector {

    // MARK: - Active buffs

    /// gameClock deadline per timed buff type; absent = not active.
    private var buffDeadlines: [PickupType: TimeInterval] = [:]

    func isBuffActive(_ type: PickupType, at clock: TimeInterval) -> Bool {
        guard let deadline = buffDeadlines[type] else { return false }
        return clock < deadline
    }

    func buffRemaining(_ type: PickupType, at clock: TimeInterval) -> TimeInterval {
        guard let deadline = buffDeadlines[type] else { return 0 }
        return max(0, deadline - clock)
    }

    /// Re-taking a buff refreshes it to a full duration rather than
    /// stacking, which keeps the multiplier bounded.
    func activateBuff(_ type: PickupType, at clock: TimeInterval) {
        guard let duration = type.duration else { return }
        buffDeadlines[type] = clock + duration
    }

    /// Drops any buff whose deadline has passed. Cheap, called each frame.
    func expireBuffs(at clock: TimeInterval) {
        buffDeadlines = buffDeadlines.filter { $0.value > clock }
    }

    /// Temporary buffs never survive a save/load or a restart — they exist
    /// only in this object, are absent from GameState entirely, and this
    /// clears them for the in-place cases (round restart, new run).
    func clearBuffs() {
        buffDeadlines.removeAll()
    }

    var damageMultiplier: CGFloat {
        buffDeadlines[.doubleDamage] != nil ? Balance.doubleDamageMultiplier : 1
    }

    var speedMultiplier: CGFloat {
        buffDeadlines[.speedBoost] != nil ? Balance.speedBoostMultiplier : 1
    }

    /// Buffs currently running, for the HUD, ordered stably so the icons
    /// don't jump around between frames.
    func activeBuffs(at clock: TimeInterval) -> [(type: PickupType, remaining: TimeInterval)] {
        PickupType.allCases.compactMap { type in
            guard let deadline = buffDeadlines[type], deadline > clock else { return nil }
            return (type, deadline - clock)
        }
    }

    // MARK: - Spawn scheduling

    private var medkitDeadline: TimeInterval?
    private var medkitSpawnedThisRound = false
    private var nextRollDeadline: TimeInterval?

    /// Called when a round starts. Schedules the guaranteed medkit for
    /// partway into the round (not instantly — a medkit sitting on the
    /// floor from second zero is just a free heal, not a decision) and arms
    /// the first non-medkit roll.
    func roundDidStart(at clock: TimeInterval) {
        medkitSpawnedThisRound = false
        medkitDeadline = clock + TimeInterval.random(
            in: Balance.medkitSpawnDelayMin...Balance.medkitSpawnDelayMax
        )
        nextRollDeadline = clock + TimeInterval.random(
            in: Balance.pickupRollIntervalMin...Balance.pickupRollIntervalMax
        )
    }

    func roundDidEnd() {
        medkitDeadline = nil
        nextRollDeadline = nil
        medkitSpawnedThisRound = false
    }

    /// Returns the pickup types that should spawn this frame (usually
    /// none). `enemiesAlive` gates the random roll only — the guaranteed
    /// medkit still lands even if the last zombie died first, so a round
    /// can't skip it.
    func typesToSpawn(at clock: TimeInterval, enemiesAlive: Bool) -> [PickupType] {
        var spawns: [PickupType] = []

        if !medkitSpawnedThisRound, let deadline = medkitDeadline, clock >= deadline {
            medkitSpawnedThisRound = true
            medkitDeadline = nil
            spawns.append(.medkit)
        }

        if enemiesAlive, let deadline = nextRollDeadline, clock >= deadline {
            nextRollDeadline = clock + TimeInterval.random(
                in: Balance.pickupRollIntervalMin...Balance.pickupRollIntervalMax
            )
            spawns.append(rollNonMedkitType())
        }

        return spawns
    }

    /// Weighted pick. Nuke is rare but not vanishing — at roughly three
    /// rolls in an average round, weight 8/100 works out to about one nuke
    /// every four rounds.
    private func rollNonMedkitType() -> PickupType {
        let weights: [(PickupType, Int)] = [
            (.doubleDamage, Balance.pickupWeightDoubleDamage),
            (.speedBoost, Balance.pickupWeightSpeedBoost),
            (.nuke, Balance.pickupWeightNuke)
        ]
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return .doubleDamage }
        var roll = Int.random(in: 0..<total)
        for (type, weight) in weights {
            if roll < weight { return type }
            roll -= weight
        }
        return .doubleDamage
    }

    // MARK: - Placement

    /// Picks a random walkable floor cell, never a wall or obstacle, and
    /// never right on top of the player. Falls back to nil rather than
    /// forcing a bad position if the map somehow has nowhere valid.
    static func randomFloorPosition(in map: MapModel, awayFrom playerPosition: CGPoint) -> CGPoint? {
        let minimumDistance = map.cellSize * 2
        var candidates: [CGPoint] = []
        for row in 0..<map.layout.rows {
            for column in 0..<map.layout.columns where map.layout.cell(column: column, row: row).isWalkable {
                let point = CGPoint(
                    x: CGFloat(column) * map.cellSize + map.cellSize / 2,
                    y: -(CGFloat(row) * map.cellSize + map.cellSize / 2)
                )
                if distance(point, playerPosition) >= minimumDistance {
                    candidates.append(point)
                }
            }
        }
        return candidates.randomElement()
    }
}
