import Foundation

/// Bolts arc from the hit enemy to nearby enemies, losing damage per jump.
final class ArcCannon: BaseWeapon {
    override var bulletBehavior: BulletBehavior {
        .chain(maxJumps: Balance.arcCannonChainMaxJumps, jumpRange: Balance.arcCannonChainRange, falloff: Balance.arcCannonChainFalloff)
    }

    init() {
        super.init(
            weaponType: .arcCannon,
            name: WeaponType.arcCannon.displayName,
            cost: WeaponType.arcCannon.cost,
            magazineSize: Balance.arcCannonMagazineSize,
            baseDamage: Balance.arcCannonDamage,
            fireRate: Balance.arcCannonFireRate,
            reloadTime: Balance.arcCannonReloadTime,
            bulletSpeed: Balance.arcCannonBulletSpeed,
            range: Balance.arcCannonRange
        )
    }
}
