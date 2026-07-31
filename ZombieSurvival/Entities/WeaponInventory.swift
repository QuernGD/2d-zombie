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

    /// The _Shoot spritesheet played on fire. Only 6 unique sheets exist for
    /// 8 weapon types (no dedicated SMG or Arc Cannon art), so SMG reuses
    /// the revolver sheet and LMG/Arc Cannon reuse Rifle/Sniper respectively
    /// (long-gun and precision/beam family resemblance). _Flicker sheets are
    /// deliberately not wired: every _Flicker sheet, including the
    /// melee-only Axe_Flicker, measures the same 7 frames — a melee weapon
    /// has no muzzle, so this reads as a shared idle/glow effect rather than
    /// a muzzle flash, not worth wiring for this pass.
    var shootSheet: SpriteSheetFrames {
        let subdirectory = "Assets/Weapons"
        switch self {
        case .pistol:
            return SpriteSheetFrames(sheetName: "pistol_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.pistolShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .smg:
            return SpriteSheetFrames(sheetName: "revolver_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.smgShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .shotgun:
            return SpriteSheetFrames(sheetName: "shotgun_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.shotgunShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .assaultRifle:
            return SpriteSheetFrames(sheetName: "rifle_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.assaultRifleShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .sniper:
            return SpriteSheetFrames(sheetName: "sniper_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.sniperShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .lmg:
            return SpriteSheetFrames(sheetName: "rifle_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.lmgShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .grenadeLauncher:
            return SpriteSheetFrames(sheetName: "rocketlauncher_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.grenadeLauncherShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
        case .arcCannon:
            return SpriteSheetFrames(sheetName: "sniper_shoot", frameSize: Balance.weaponFrameSize, frameCount: Balance.arcCannonShootFrameCount, subdirectory: subdirectory, timePerFrame: Balance.weaponShootFrameTime)
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

    /// Load-time restoration only — sets the active slot directly, bypassing
    /// swapActive's "must already hold a weapon" guard (the caller is
    /// expected to have equipped every slot first).
    func setActiveIndex(_ index: Int) {
        guard slots.indices.contains(index), slots[index] != nil else { return }
        activeIndex = index
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
