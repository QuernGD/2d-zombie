import CoreGraphics

/// A serializable snapshot of everything needed to describe (and, later,
/// restore) a run. No save/load exists yet, but keeping this Codable and
/// free of SpriteKit types from day one means a future save system only
/// needs to read/write this struct.
struct GameState: Codable, Equatable {
    var schemaVersion: Int = 2

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

    var coins: Int = 0
    var ownedWeapons: [WeaponType] = [.pistol]
    var overclockTiers: [WeaponType: Int] = [:]
    var activeSlot: Int = 0
    var ownedPerks: Set<Perk> = []
}
