import Foundation

/// Huge single-shot damage and range, tiny magazine, slow fire rate.
final class Sniper: BaseWeapon {
    init() {
        super.init(
            weaponType: .sniper,
            name: WeaponType.sniper.displayName,
            cost: WeaponType.sniper.cost,
            magazineSize: Balance.sniperMagazineSize,
            baseDamage: Balance.sniperDamage,
            fireRate: Balance.sniperFireRate,
            reloadTime: Balance.sniperReloadTime,
            bulletSpeed: Balance.sniperBulletSpeed,
            range: Balance.sniperRange
        )
    }
}
