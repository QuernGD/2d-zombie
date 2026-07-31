import Foundation

/// Huge magazine, very high fire rate, long reload to compensate.
final class LMG: BaseWeapon {
    init() {
        super.init(
            weaponType: .lmg,
            name: WeaponType.lmg.displayName,
            cost: WeaponType.lmg.cost,
            magazineSize: Balance.lmgMagazineSize,
            baseDamage: Balance.lmgDamage,
            fireRate: Balance.lmgFireRate,
            reloadTime: Balance.lmgReloadTime,
            bulletSpeed: Balance.lmgBulletSpeed,
            range: Balance.lmgRange
        )
    }
}
