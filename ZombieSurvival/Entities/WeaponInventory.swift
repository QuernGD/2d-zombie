import Foundation

/// The full weapon catalog. Each case knows its shop cost, display name,
/// and how to build a fresh instance — the single place that maps a
/// persisted identifier (GameState, save data) back to a live Weapon.
enum WeaponType: String, Codable, CaseIterable {
    case pistol
    case smg
    case shotgun
    case assaultRifle
    case sniper
    case lmg
    case grenadeLauncher
    case arcCannon

    var displayName: String {
        switch self {
        case .pistol: return "Pistol"
        case .smg: return "SMG"
        case .shotgun: return "Shotgun"
        case .assaultRifle: return "Assault Rifle"
        case .sniper: return "Sniper"
        case .lmg: return "LMG"
        case .grenadeLauncher: return "Grenade Launcher"
        case .arcCannon: return "Arc Cannon"
        }
    }

    var cost: Int {
        switch self {
        case .pistol: return 0
        case .smg: return Balance.smgCost
        case .shotgun: return Balance.shotgunCost
        case .assaultRifle: return Balance.assaultRifleCost
        case .sniper: return Balance.sniperCost
        case .lmg: return Balance.lmgCost
        case .grenadeLauncher: return Balance.grenadeLauncherCost
        case .arcCannon: return Balance.arcCannonCost
        }
    }

    func makeWeapon() -> Weapon {
        switch self {
        case .pistol: return Pistol()
        case .smg: return SMG()
        case .shotgun: return Shotgun()
        case .assaultRifle: return AssaultRifle()
        case .sniper: return Sniper()
        case .lmg: return LMG()
        case .grenadeLauncher: return GrenadeLauncher()
        case .arcCannon: return ArcCannon()
        }
    }
}

/// Two weapon slots plus which one is active. Slot 0 always starts with the
/// free Pistol. Buying a weapon while both slots are full requires the shop
/// to ask the player which slot to replace (WeaponInventory itself has no
/// opinion on that — it just equips whatever slot it's told to).
final class WeaponInventory {
    static let slotCount = 2

    private(set) var slots: [Weapon?]
    private(set) var activeIndex: Int = 0

    var activeWeapon: Weapon? { slots[activeIndex] }
    var ownedTypes: Set<WeaponType> { Set(slots.compactMap { $0?.weaponType }) }
    var hasEmptySlot: Bool { slots.contains { $0 == nil } }

    init() {
        slots = Array(repeating: nil, count: Self.slotCount)
        slots[0] = Pistol()
    }

    func firstEmptySlot() -> Int? {
        slots.firstIndex { $0 == nil }
    }

    /// Swaps to the other slot only if it actually holds a weapon.
    @discardableResult
    func swapActive() -> Bool {
        let other = 1 - activeIndex
        guard slots[other] != nil else { return false }
        activeIndex = other
        return true
    }

    func equip(_ weapon: Weapon, inSlot slot: Int) {
        guard slots.indices.contains(slot) else { return }
        slots[slot] = weapon
    }

    /// Re-applies perk-derived multipliers (Overdrive, Rapid Hands) to every
    /// owned weapon. Overclock's own tier bonus lives on the weapon itself
    /// and is never touched here, so calling this repeatedly is always safe.
    func refreshModifiers(perks: Set<Perk>) {
        for weapon in slots.compactMap({ $0 }) {
            weapon.fireRateMultiplier = perks.contains(.overdrive) ? Balance.overdriveFireRateMultiplier : 1.0
            weapon.reloadTimeMultiplier = perks.contains(.rapidHands) ? Balance.rapidHandsReloadMultiplier : 1.0
        }
    }
}
