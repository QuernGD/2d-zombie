import CoreGraphics
import Foundation

/// The player as a first-person camera: a position and a facing angle,
/// plus all the inventory/perk/health state that carried over unchanged
/// from the top-down build (ShopScene talks to exactly the same API).
///
/// No longer an SKNode — in first person the player is never drawn, so
/// there's nothing to put in the scene graph.
final class Player {
    let baseMaxHealth: CGFloat
    let baseMoveSpeed: CGFloat
    private(set) var health: CGFloat
    let inventory: WeaponInventory
    private(set) var perks: Set<Perk> = []

    /// World position (x right, y up), in the same units MapModel uses.
    var position: CGPoint = .zero
    /// Facing angle: 0 = +x, increasing counter-clockwise.
    var facingAngle: CGFloat = 0

    var isAlive: Bool { health > 0 }
    var activeWeapon: Weapon? { inventory.activeWeapon }

    /// Base value doubled by the Vitality perk.
    var maxHealth: CGFloat {
        baseMaxHealth * (perks.contains(.vitality) ? Balance.vitalityMaxHealthMultiplier : 1)
    }

    /// Base value boosted by the Sprinter perk.
    var moveSpeed: CGFloat {
        baseMoveSpeed * (perks.contains(.sprinter) ? Balance.sprinterMoveSpeedMultiplier : 1)
    }

    init(maxHealth: CGFloat = Balance.playerMaxHealth, moveSpeed: CGFloat = Balance.playerMoveSpeed) {
        self.baseMaxHealth = maxHealth
        self.health = maxHealth
        self.baseMoveSpeed = moveSpeed
        self.inventory = WeaponInventory()
    }

    // MARK: - Movement

    /// `forward` and `strafe` are -1...1 in the player's own frame; this
    /// rotates them into world space and slides along walls via the same
    /// resolveCollision the top-down build used.
    func move(forward: CGFloat, strafe: CGFloat, deltaTime: TimeInterval, solidRects: [CGRect]) {
        guard forward != 0 || strafe != 0 else { return }
        let cosAngle = cos(facingAngle)
        let sinAngle = sin(facingAngle)
        // Strafe right is forward rotated -90°.
        var dx = cosAngle * forward + sinAngle * strafe
        var dy = sinAngle * forward - cosAngle * strafe

        let magnitude = sqrt(dx * dx + dy * dy)
        if magnitude > 1 {
            dx /= magnitude
            dy /= magnitude
        }
        let step = moveSpeed * CGFloat(deltaTime)
        let attempted = CGPoint(x: position.x + dx * step, y: position.y + dy * step)
        position = resolveCollision(from: position, to: attempted, radius: Balance.playerRadius, solidRects: solidRects)
    }

    func turn(by radians: CGFloat) {
        facingAngle += radians
        // Keep the angle bounded so it can't drift into float mush over a
        // long run of continuous turning.
        if facingAngle > .pi * 2 { facingAngle -= .pi * 2 }
        if facingAngle < 0 { facingAngle += .pi * 2 }
    }

    // MARK: - Health, perks (unchanged behaviour from the top-down build)

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
    }

    /// Load-time restoration only — sets perks directly with no Vitality
    /// health top-up (health is restored separately, right after this).
    func restorePerks(_ restoredPerks: Set<Perk>) {
        perks = restoredPerks
    }

    /// Load-time restoration only — sets health directly (clamped to
    /// maxHealth, which depends on perks, so call this after restorePerks).
    func restoreHealth(_ amount: CGFloat) {
        health = min(max(0, amount), maxHealth)
    }

    /// One-time purchase effect. Vitality tops up current health by the
    /// exact amount max health just increased, so buying it never makes an
    /// already-hurt player's health bar look worse.
    func applyPerk(_ perk: Perk) {
        guard !perks.contains(perk) else { return }
        let previousMaxHealth = maxHealth
        perks.insert(perk)
        if perk == .vitality {
            health += (maxHealth - previousMaxHealth)
        }
        inventory.refreshModifiers(perks: perks)
    }
}
