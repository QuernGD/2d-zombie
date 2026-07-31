import SpriteKit

/// The only enemy type for this phase: walks straight at the player and
/// deals contact damage on an attack cooldown.
///
/// Animation: idle while stationary, move while pursuing, attack (one-shot)
/// on contact. Frames are expected at ZombieSurvival/Assets/Enemies/Zombie/
/// as skeleton-idle_0...16, skeleton-move_0...16, skeleton-attack_0...8 (see
/// Assets/README.md). Until those exist, AssetProvider's fallback keeps this
/// rendering as the Phase 1 placeholder circle with no animation.
final class Walker: SKNode, Enemy {
    var node: SKNode { self }

    private(set) var health: CGFloat
    let maxHealth: CGFloat
    let moveSpeed: CGFloat = Balance.zombieMoveSpeed
    let contactDamage: CGFloat = Balance.zombieContactDamage
    let attackCooldown: TimeInterval = Balance.zombieAttackCooldown

    private var lastAttackTime: TimeInterval = -.infinity

    private enum AnimState { case idle, move, attack }
    private var currentAnimState: AnimState = .idle

    private let visualSprite: SKSpriteNode?
    private let idleTextures: [SKTexture]
    private let moveTextures: [SKTexture]
    private let attackTextures: [SKTexture]

    var isAlive: Bool { health > 0 }

    init(health: CGFloat) {
        self.health = health
        self.maxHealth = health

        let zombieAssetPath = "Assets/Enemies/Zombie"
        idleTextures = AssetProvider.loadTextures(AnimationFrameSequence(baseName: "skeleton-idle", count: 17, timePerFrame: Balance.zombieIdleFrameTime, subdirectory: zombieAssetPath)) ?? []
        moveTextures = AssetProvider.loadTextures(AnimationFrameSequence(baseName: "skeleton-move", count: 17, timePerFrame: Balance.zombieMoveFrameTime, subdirectory: zombieAssetPath)) ?? []
        attackTextures = AssetProvider.loadTextures(AnimationFrameSequence(baseName: "skeleton-attack", count: 9, timePerFrame: Balance.zombieAttackFrameTime, subdirectory: zombieAssetPath)) ?? []

        if let firstIdleFrame = idleTextures.first {
            let sprite = SKSpriteNode(texture: firstIdleFrame)
            sprite.size = CGSize(width: Balance.zombieRadius * 2, height: Balance.zombieRadius * 2)
            visualSprite = sprite
        } else {
            visualSprite = nil
        }

        super.init()
        zPosition = 50
        name = "walker"

        if let visualSprite {
            addChild(visualSprite)
        } else {
            addChild(AssetProvider.makeNode(for: .walker, radius: Balance.zombieRadius, fillColor: .systemRed))
        }
        playAnimation(.idle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Straight-line pursuit. Sufficient for a single open arena; swap this
    /// for real pathfinding (e.g. around obstacles) without touching
    /// anything outside this method.
    func update(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard isAlive else { return }
        // Let the one-shot attack animation play out undisturbed; the
        // walker holds still for its duration (attackCooldown is longer
        // than the animation, so this never blocks a follow-up attack).
        guard !isPlayingAttackAnimation else { return }

        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 1 else {
            playAnimation(.idle)
            return
        }
        let step = moveSpeed * CGFloat(deltaTime)
        position = CGPoint(x: position.x + dx / dist * step, y: position.y + dy / dist * step)
        if let visualSprite, abs(dx) > 0.01 {
            visualSprite.xScale = (dx < 0 ? -1 : 1) * abs(visualSprite.xScale)
        }
        playAnimation(.move)
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
    }

    func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    func registerAttack(at time: TimeInterval) {
        lastAttackTime = time
        playAnimation(.attack)
    }

    private var isPlayingAttackAnimation: Bool {
        currentAnimState == .attack && visualSprite?.action(forKey: "anim") != nil
    }

    private func playAnimation(_ state: AnimState) {
        guard let visualSprite else { return }
        guard currentAnimState != state || visualSprite.action(forKey: "anim") == nil else { return }

        let textures: [SKTexture]
        let timePerFrame: TimeInterval
        let repeatsForever: Bool
        switch state {
        case .idle:
            textures = idleTextures
            timePerFrame = Balance.zombieIdleFrameTime
            repeatsForever = true
        case .move:
            textures = moveTextures
            timePerFrame = Balance.zombieMoveFrameTime
            repeatsForever = true
        case .attack:
            textures = attackTextures
            timePerFrame = Balance.zombieAttackFrameTime
            repeatsForever = false
        }
        // Only commit to the new state once we know it can actually play —
        // otherwise (e.g. attack frames missing while idle/move exist) we'd
        // set currentAnimState to .attack without starting anything, and
        // isPlayingAttackAnimation would then permanently block update().
        guard !textures.isEmpty else { return }
        currentAnimState = state
        let animate = SKAction.animate(with: textures, timePerFrame: timePerFrame)
        visualSprite.run(repeatsForever ? .repeatForever(animate) : animate, withKey: "anim")
    }
}
