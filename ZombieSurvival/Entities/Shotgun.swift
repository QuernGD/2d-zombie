import Foundation

/// Fires a spread of pellets; short range, slow pump-action fire rate.
final class Shotgun: BaseWeapon {
    init() {
        super.init(
            weaponType: .shotgun,
            name: WeaponType.shotgun.displayName,
            cost: WeaponType.shotgun.cost,
            magazineSize: Balance.shotgunMagazineSize,
            baseDamage: Balance.shotgunDamage,
            fireRate: Balance.shotgunFireRate,
            reloadTime: Balance.shotgunReloadTime,
            bulletSpeed: Balance.shotgunBulletSpeed,
            range: Balance.shotgunRange,
            pelletCount: Balance.shotgunPelletCount,
            spreadAngle: Balance.shotgunSpreadAngle
        )
    }
}
