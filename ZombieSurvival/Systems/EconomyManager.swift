import CoreGraphics

/// Owns the player's coin balance and the spend/afford checks every shop
/// purchase routes through. Deliberately doesn't know about Player or
/// WeaponInventory — ShopScene is the one that spends coins here and then
/// applies the effect to the live game objects.
final class EconomyManager {
    private(set) var coins: Int = 0

    func addCoins(_ amount: Int) {
        coins += max(0, amount)
    }

    func canAfford(_ cost: Int) -> Bool {
        coins >= cost
    }

    @discardableResult
    func spend(_ cost: Int) -> Bool {
        guard canAfford(cost) else { return false }
        coins -= cost
        return true
    }

    /// Mystery Crate roll: every non-Pistol weapon is a possible result,
    /// weighted so weapons the player doesn't already own are far more likely.
    func rollMysteryCrateWeapon(owned: Set<WeaponType>) -> WeaponType {
        let pool = WeaponType.allCases.filter { $0 != .pistol }
        let weights = pool.map { owned.contains($0) ? Balance.ownedWeaponCrateWeight : Balance.unownedWeaponCrateWeight }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement() ?? .smg }
        var roll = CGFloat.random(in: 0..<total)
        for (type, weight) in zip(pool, weights) {
            if roll < weight { return type }
            roll -= weight
        }
        return pool.last ?? .smg
    }
}
