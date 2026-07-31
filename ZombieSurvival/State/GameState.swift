import CoreGraphics

/// A serializable snapshot of everything needed to describe (and, later,
/// restore) a run. Free of SpriteKit types so SaveManager can Codable it
/// straight to/from a Documents-directory JSON file.
struct GameState: Codable, Equatable {
    var schemaVersion: Int = 3

    var round: Int = 0
    var isRoundActive: Bool = false
    var isGameOver: Bool = false

    var playerHealth: CGFloat = Balance.playerMaxHealth
    var playerMaxHealth: CGFloat = Balance.playerMaxHealth

    var ammoInMagazine: Int = Balance.pistolMagazineSize
    var magazineSize: Int = Balance.pistolMagazineSize
    var isReloading: Bool = false

    var controlSchemeType: ControlSchemeType = .dualStick

    // MARK: - Economy / inventory (Phase 2)

    var coins: Int = 20000000
    /// Exactly WeaponInventory.slotCount elements, index-aligned with
    /// WeaponInventory.slots (nil = empty slot). Needs to preserve slot
    /// order/identity (not just "which types are owned") so loading a save
    /// can rebuild the inventory with weapons in the same slots they were
    /// equipped in — a flat unordered list of owned types isn't enough.
    var weaponSlots: [WeaponType?] = [.pistol, nil]
    var overclockTiers: [WeaponType: Int] = [:]
    var activeSlot: Int = 0
    var ownedPerks: Set<Perk> = []

    // MARK: - Run setup (Phase 3)

    /// Chosen at run start and locked for the run's duration.
    var selectedMap: MapID = .original
    var difficulty: Difficulty = .medium
}
