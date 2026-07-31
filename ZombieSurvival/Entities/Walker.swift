import SpriteKit

/// The only enemy type for this phase: walks straight at the player and
/// deals contact damage on an attack cooldown.
final class Walker: SKNode, Enemy {
    var node: SKNode { self }

    private(set) var health: CGFloat
    let maxHealth: CGFloat
    let moveSpeed: CGFloat = Balance.zombieMoveSpeed
    let contactDamage: CGFloat = Balance.zombieContactDamage
    let attackCooldown: TimeInterval = Balance.zombieAttackCooldown

    private var lastAttackTime: TimeInterval = -.infinity

    var isAlive: Bool { health > 0 }

    init(health: CGFloat) {
        self.health = health
        self.maxHealth = health
        super.init()
        zPosition = 50
        name = "walker"
        addChild(AssetProvider.makeNode(for: .walker, radius: Balance.zombieRadius, fillColor: .systemRed))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Straight-line pursuit. Sufficient for a single open arena; swap this
    /// for real pathfinding (e.g. around obstacles) without touching
    /// anything outside this method.
    func update(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard isAlive else { return }
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 1 else { return }
        let step = moveSpeed * CGFloat(deltaTime)
        position = CGPoint(x: position.x + dx / dist * step, y: position.y + dy / dist * step)
        zRotation = atan2(dy, dx)
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
    }

    func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    func registerAttack(at time: TimeInterval) {
        lastAttackTime = time
    }
}
