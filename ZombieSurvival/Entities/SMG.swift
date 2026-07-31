import Foundation

/// High fire rate, low damage per hit, big magazine.
final class SMG: BaseWeapon {
    init() {
        super.init(
            weaponType: .smg,
            name: WeaponType.smg.displayName,
            cost: WeaponType.smg.cost,
            magazineSize: Balance.smgMagazineSize,
            baseDamage: Balance.smgDamage,
            fireRate: Balance.smgFireRate,
            reloadTime: Balance.smgReloadTime,
            bulletSpeed: Balance.smgBulletSpeed,
            range: Balance.smgRange
        )
    }
}
