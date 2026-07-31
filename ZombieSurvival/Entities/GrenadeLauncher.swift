import Foundation

/// Lobs slow-moving rounds that explode in an area on impact — or on
/// reaching max range, so a miss still detonates wherever it lands.
final class GrenadeLauncher: BaseWeapon {
    override var bulletBehavior: BulletBehavior { .aoe(radius: Balance.grenadeLauncherAoeRadius) }

    init() {
        super.init(
            weaponType: .grenadeLauncher,
            name: WeaponType.grenadeLauncher.displayName,
            cost: WeaponType.grenadeLauncher.cost,
            magazineSize: Balance.grenadeLauncherMagazineSize,
            baseDamage: Balance.grenadeLauncherDamage,
            fireRate: Balance.grenadeLauncherFireRate,
            reloadTime: Balance.grenadeLauncherReloadTime,
            bulletSpeed: Balance.grenadeLauncherBulletSpeed,
            range: Balance.grenadeLauncherRange
        )
    }
}
