import SpriteKit

/// Common behavior every enemy type must provide. GameScene and WaveManager
/// only ever talk to this protocol, so adding a Runner, Spitter, etc. later
/// is a new file, not a change to existing systems.
protocol Enemy: AnyObject {
    /// The scene-graph node representing this enemy. For SKNode subclasses
    /// that also conform to Enemy, this is simply `self`.
    var node: SKNode { get }

    var health: CGFloat { get }
    var maxHealth: CGFloat { get }
    var moveSpeed: CGFloat { get }
    var contactDamage: CGFloat { get }
    var attackCooldown: TimeInterval { get }
    var isAlive: Bool { get }

    func update(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint)
    func takeDamage(_ amount: CGFloat)
    func canAttack(at time: TimeInterval) -> Bool
    func registerAttack(at time: TimeInterval)
}
