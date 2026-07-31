import Foundation
import CoreGraphics

/// Abstracts "a thing the player shoots with" so future weapons (shotgun,
/// SMG, etc.) can be swapped in without touching Player or GameScene.
protocol Weapon: AnyObject {
    var magazineSize: Int { get }
    var ammoInMagazine: Int { get }
    var isReloading: Bool { get }
    var fireRate: TimeInterval { get }
    var damage: CGFloat { get }
    var bulletSpeed: CGFloat { get }
    var range: CGFloat { get }

    func canFire(at time: TimeInterval) -> Bool
    @discardableResult
    func fire(at time: TimeInterval) -> Bool
    func update(currentTime: TimeInterval)
}

/// Starting pistol: infinite reserve ammo, only the magazine is tracked.
/// Reloading always tops the magazine back up to full.
final class Pistol: Weapon {
    let magazineSize = Balance.pistolMagazineSize
    private(set) var ammoInMagazine: Int
    private(set) var isReloading: Bool = false
    let fireRate = Balance.pistolFireRate
    let damage = Balance.pistolDamage
    let bulletSpeed = Balance.pistolBulletSpeed
    let range = Balance.pistolBulletRange

    private var lastFireTime: TimeInterval = -.infinity
    private var reloadStartTime: TimeInterval = 0

    init() {
        ammoInMagazine = magazineSize
    }

    func canFire(at time: TimeInterval) -> Bool {
        !isReloading && ammoInMagazine > 0 && (time - lastFireTime) >= fireRate
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
        guard isReloading, currentTime - reloadStartTime >= Balance.pistolReloadTime else { return }
        isReloading = false
        ammoInMagazine = magazineSize // infinite reserve: always tops off
    }
}
