import Foundation

/// Balanced all-rounder: solid damage, fire rate, and range.
final class AssaultRifle: BaseWeapon {
    init() {
        super.init(
            weaponType: .assaultRifle,
            name: WeaponType.assaultRifle.displayName,
            cost: WeaponType.assaultRifle.cost,
            magazineSize: Balance.assaultRifleMagazineSize,
            baseDamage: Balance.assaultRifleDamage,
            fireRate: Balance.assaultRifleFireRate,
            reloadTime: Balance.assaultRifleReloadTime,
            bulletSpeed: Balance.assaultRifleBulletSpeed,
            range: Balance.assaultRifleRange
        )
    }
}
