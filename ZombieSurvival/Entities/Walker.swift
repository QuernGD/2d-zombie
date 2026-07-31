import SpriteKit

/// The only enemy type for this phase: walks straight at the player and
/// deals contact damage on an attack cooldown.
///
/// Visuals: each instance is randomly assigned one of 4 zombie variants
/// (no enemy tier system exists yet — Walker is still the only enemy type,
/// so there's nothing to map a variant to besides chance) and loads its
/// idle/run/hit/knocked/death frames from Assets/Characters/Zombie<variant>/.
/// The art pack has no dedicated "attack" sheet, so contact damage stays
/// purely instant/math-based (as in Phases 1-3) with no unique animation;
/// Hit and Knocked are instead wired as light/heavy damage-*reaction*
/// flinches — Hit for a normal hit, Knocked for a single hit at or above
/// Balance.zombieKnockedDamageThreshold.
final class Walker: SKNode, Enemy {
    var node: SKNode { self }

    private(set) var health: CGFloat
    let maxHealth: CGFloat
    let moveSpeed: CGFloat = Balance.zombieMoveSpeed
    /// Per-instance rather than a fixed constant so WaveManager can scale it
    /// by the run's difficulty multiplier.
    let contactDamage: CGFloat
    let attackCooldown: TimeInterval = Balance.zombieAttackCooldown
    let zombieVariant: Int

    private var lastAttackTime: TimeInterval = -.infinity

    private enum AnimState { case idle, run, hit, knocked }
    private var currentAnimState: AnimState = .idle

    private let visualSprite: SKSpriteNode?
    private let idleTextures: [SKTexture]
    private let runTextures: [SKTexture]
    private let hitTextures: [SKTexture]
    private let knockedTextures: [SKTexture]
    private let deathTextures: [SKTexture]

    var isAlive: Bool { health > 0 }

    init(health: CGFloat, contactDamage: CGFloat = Balance.zombieContactDamage, zombieVariant: Int = Int.random(in: 1...4)) {
        self.health = health
        self.maxHealth = health
        self.contactDamage = contactDamage
        self.zombieVariant = zombieVariant

        let assetPath = "Assets/Characters/Zombie\(zombieVariant)"
        func sheet(_ name: String, frameCount: Int) -> SpriteSheetFrames {
            SpriteSheetFrames(sheetName: name, frameSize: Balance.characterFrameSize, frameCount: frameCount, subdirectory: assetPath)
        }

        idleTextures = AssetProvider.loadSpriteSheetTextures(sheet("idle", frameCount: Balance.characterIdleFrameCount)) ?? []
        runTextures = AssetProvider.loadSpriteSheetTextures(sheet("run", frameCount: Balance.characterRunFrameCount)) ?? []
        hitTextures = AssetProvider.loadSpriteSheetTextures(sheet("hit", frameCount: Balance.characterHitFrameCount)) ?? []
        knockedTextures = AssetProvider.loadSpriteSheetTextures(sheet("knocked", frameCount: Balance.characterKnockedFrameCount)) ?? []

        // Zombie1/2 ship two death variants, Zombie3/4 only one — pick
        // randomly, then fall back to death1 if the random pick doesn't
        // exist for this variant (rather than falling all the way back to
        // the scale+fade placeholder when death1 was actually available).
        let preferredDeath = Bool.random() ? "death2" : "death1"
        var death = AssetProvider.loadSpriteSheetTextures(sheet(preferredDeath, frameCount: Balance.characterDeathFrameCount))
        if death == nil, preferredDeath == "death2" {
            death = AssetProvider.loadSpriteSheetTextures(sheet("death1", frameCount: Balance.characterDeathFrameCount))
        }
        deathTextures = death ?? []

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
        // Let a hit/knocked reaction play out undisturbed, same idea as the
        // old one-shot attack animation: brief hit-stun while it plays.
        guard !isPlayingReactionAnimation else { return }

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
        playAnimation(.run)
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
        guard isAlive else { return } // death animation is triggered separately via playDeathAnimation()
        playAnimation(amount >= Balance.zombieKnockedDamageThreshold ? .knocked : .hit)
    }

    func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    func registerAttack(at time: TimeInterval) {
        lastAttackTime = time
    }

    /// Plays the real death animation (random death1/death2 variant, picked
    /// at spawn time) and removes this node once it finishes. Falls back to
    /// the Phase 2 scale+fade placeholder only if this variant's death
    /// frames failed to load entirely.
    func playDeathAnimation() {
        removeAllActions()
        visualSprite?.removeAllActions()

        if !deathTextures.isEmpty, let visualSprite {
            let animate = SKAction.animate(with: deathTextures, timePerFrame: Balance.characterDeathFrameTime)
            visualSprite.run(.sequence([animate, .removeFromParent()]))
            run(.sequence([.wait(forDuration: Balance.characterDeathFrameTime * Double(deathTextures.count)), .removeFromParent()]))
        } else {
            let shrink = SKAction.scale(to: 0, duration: Balance.zombieDeathEffectDuration)
            let fade = SKAction.fadeOut(withDuration: Balance.zombieDeathEffectDuration)
            run(.sequence([.group([shrink, fade]), .removeFromParent()]))
        }
    }

    private var isPlayingReactionAnimation: Bool {
        (currentAnimState == .hit || currentAnimState == .knocked) && visualSprite?.action(forKey: "anim") != nil
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
            timePerFrame = Balance.characterIdleFrameTime
            repeatsForever = true
        case .run:
            textures = runTextures
            timePerFrame = Balance.characterRunFrameTime
            repeatsForever = true
        case .hit:
            textures = hitTextures
            timePerFrame = Balance.characterHitFrameTime
            repeatsForever = false
        case .knocked:
            textures = knockedTextures
            timePerFrame = Balance.characterKnockedFrameTime
            repeatsForever = false
        }
        // Only commit to the new state once we know it can actually play —
        // otherwise (e.g. hit frames missing while idle/run exist) we'd set
        // currentAnimState without starting anything, permanently blocking
        // update() via isPlayingReactionAnimation.
        guard !textures.isEmpty else { return }
        currentAnimState = state
        let animate = SKAction.animate(with: textures, timePerFrame: timePerFrame)
        if repeatsForever {
            visualSprite.run(.repeatForever(animate), withKey: "anim")
        } else {
            visualSprite.run(.sequence([animate, .run { [weak self] in self?.currentAnimState = .idle }]), withKey: "anim")
        }
    }
}
