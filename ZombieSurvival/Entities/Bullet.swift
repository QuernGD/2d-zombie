import SpriteKit

/// What happens when a bullet connects (or, for AoE, runs out of range).
/// GameScene reads this off the bullet at resolution time; the bullet
/// itself doesn't need to know how to apply damage.
enum BulletBehavior {
    case standard
    case aoe(radius: CGFloat)
    case chain(maxJumps: Int, jumpRange: CGFloat, falloff: CGFloat)
}

/// A traveling projectile. Movement and range are simulated manually each
/// frame by GameScene rather than via SpriteKit physics, since collision
/// checks stay simple (circle vs. circle) with the low entity counts here.
final class Bullet: SKNode {
    let velocity: CGVector
    let damage: CGFloat
    let maxRange: CGFloat
    let behavior: BulletBehavior
    private var travelled: CGFloat = 0

    init(velocity: CGVector, damage: CGFloat, maxRange: CGFloat, behavior: BulletBehavior = .standard) {
        self.velocity = velocity
        self.damage = damage
        self.maxRange = maxRange
        self.behavior = behavior
        super.init()
        zPosition = 75
        name = "bullet"
        addChild(AssetProvider.makeNode(for: .bullet, radius: Balance.pistolBulletRadius, fillColor: .yellow))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Advances the bullet and returns false once it has exceeded its range.
    @discardableResult
    func advance(deltaTime: TimeInterval) -> Bool {
        let dx = velocity.dx * CGFloat(deltaTime)
        let dy = velocity.dy * CGFloat(deltaTime)
        position = CGPoint(x: position.x + dx, y: position.y + dy)
        travelled += sqrt(dx * dx + dy * dy)
        return travelled < maxRange
    }
}
