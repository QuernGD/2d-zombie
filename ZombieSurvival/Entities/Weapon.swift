import Foundation
import CoreGraphics

/// Abstracts "a thing the player shoots with" so weapons can be swapped in
/// and out of a WeaponInventory slot without touching Player or GameScene.
protocol Weapon: AnyObject {
    var weaponType: WeaponType { get }
    var name: String { get }
    var cost: Int { get }

    var magazineSize: Int { get }
    var ammoInMagazine: Int { get }
    var isReloading: Bool { get }

    var baseDamage: CGFloat { get }
    /// 0 = none, 1 = Tier 1, 2 = Tier 2. Persists per weapon instance.
    var overclockTier: Int { get set }
    var overclockMultiplier: CGFloat { get }
    /// baseDamage * overclockMultiplier.
    var damage: CGFloat { get }

    var fireRate: TimeInterval { get }
    /// Perk-derived (Overdrive). WeaponInventory.refreshModifiers keeps this
    /// in sync; overclock's own fire-rate bonus is applied internally and
    /// does not flow through here, so the two never double-stack.
    var fireRateMultiplier: CGFloat { get set }

    var reloadTime: TimeInterval { get }
    /// Perk-derived (Rapid Hands), kept in sync the same way.
    var reloadTimeMultiplier: CGFloat { get set }

    var bulletSpeed: CGFloat { get }
    var range: CGFloat { get }
    var pelletCount: Int { get }
    var spreadAngle: CGFloat { get }
    var bulletBehavior: BulletBehavior { get }

    func canFire(at time: TimeInterval) -> Bool
    @discardableResult
    func fire(at time: TimeInterval) -> Bool
    func startReload(at time: TimeInterval)
    func update(currentTime: TimeInterval)
    /// Instantly tops the magazine and cancels any in-progress reload.
    func refillMagazine()
}

/// Shared implementation for every weapon: magazine/reload/fire-rate timing
/// and the overclock-driven damage formula. Concrete weapons (Pistol, SMG,
/// Shotgun, ...) just supply stats through the initializer and, for special
/// ammo types, override `bulletBehavior`.
class BaseWeapon: Weapon {
    let weaponType: WeaponType
    let name: String
    let cost: Int

    let magazineSize: Int
    private(set) var ammoInMagazine: Int
    private(set) var isReloading: Bool = false

    let baseDamage: CGFloat
    var overclockTier: Int = 0
    var overclockMultiplier: CGFloat {
        switch overclockTier {
        case 1: return Balance.overclockTier1DamageMultiplier
        case 2: return Balance.overclockTier2DamageMultiplier
        default: return 1.0
        }
    }
    var damage: CGFloat { baseDamage * overclockMultiplier }

    let fireRate: TimeInterval
    var fireRateMultiplier: CGFloat = 1.0

    let reloadTime: TimeInterval
    var reloadTimeMultiplier: CGFloat = 1.0

    let bulletSpeed: CGFloat
    let range: CGFloat
    let pelletCount: Int
    let spreadAngle: CGFloat
    var bulletBehavior: BulletBehavior { .standard }

    private var lastFireTime: TimeInterval = -.infinity
    private var reloadStartTime: TimeInterval = 0

    init(
        weaponType: WeaponType,
        name: String,
        cost: Int,
        magazineSize: Int,
        baseDamage: CGFloat,
        fireRate: TimeInterval,
        reloadTime: TimeInterval,
        bulletSpeed: CGFloat,
        range: CGFloat,
        pelletCount: Int = 1,
        spreadAngle: CGFloat = 0
    ) {
        self.weaponType = weaponType
        self.name = name
        self.cost = cost
        self.magazineSize = magazineSize
        self.ammoInMagazine = magazineSize
        self.baseDamage = baseDamage
        self.fireRate = fireRate
        self.reloadTime = reloadTime
        self.bulletSpeed = bulletSpeed
        self.range = range
        self.pelletCount = pelletCount
        self.spreadAngle = spreadAngle
    }

    private var effectiveFireRate: TimeInterval {
        let tierBonus: CGFloat = overclockTier == 2 ? Balance.overclockTier2FireRateMultiplier : 1.0
        return fireRate / (tierBonus * fireRateMultiplier)
    }

    private var effectiveReloadTime: TimeInterval {
        reloadTime * reloadTimeMultiplier
    }

    func canFire(at time: TimeInterval) -> Bool {
        !isReloading && ammoInMagazine > 0 && (time - lastFireTime) >= effectiveFireRate
    }

    @discardableResult
    func fire(at time: TimeInterval) -> Bool {
        guard canFire(at: time) else { return false }
        ammoInMagazine -= 1
        lastFireTime = time
        if ammoInMagazine == 0 {
            startReload(at: time)
        }
        return true
    }

    func startReload(at time: TimeInterval) {
        guard !isReloading, ammoInMagazine < magazineSize else { return }
        isReloading = true
        reloadStartTime = time
    }

    func update(currentTime: TimeInterval) {
        guard isReloading, currentTime - reloadStartTime >= effectiveReloadTime else { return }
        isReloading = false
        ammoInMagazine = magazineSize // infinite reserve: always tops off
    }

    func refillMagazine() {
        ammoInMagazine = magazineSize
        isReloading = false
    }
}

/// Starting pistol: free, always owned, infinite reserve ammo.
final class Pistol: BaseWeapon {
    init() {
        super.init(
            weaponType: .pistol,
            name: WeaponType.pistol.displayName,
            cost: WeaponType.pistol.cost,
            magazineSize: Balance.pistolMagazineSize,
            baseDamage: Balance.pistolDamage,
            fireRate: Balance.pistolFireRate,
            reloadTime: Balance.pistolReloadTime,
            bulletSpeed: Balance.pistolBulletSpeed,
            range: Balance.pistolBulletRange
        )
    }
}
