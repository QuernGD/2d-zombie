import SpriteKit

/// The player-controlled character. Visuals mirror Walker's pattern: an
/// idle/run/hit/death animation state machine wired from
/// Assets/Characters/Player/, falling back to the Phase 1 placeholder
/// circle (no animation) if even the idle frames fail to load. The brief
/// only lists Player_idle/run/Hit/Death (no Player_knocked), so Hit alone
/// covers the damage-reaction flinch.
final class Player: SKNode {
    let baseMaxHealth: CGFloat
    let baseMoveSpeed: CGFloat
    private(set) var health: CGFloat
    private(set) var facingAngle: CGFloat = 0
    let inventory: WeaponInventory
    private(set) var perks: Set<Perk> = []

    private enum AnimState { case idle, run, hit }
    private var currentAnimState: AnimState = .idle

    private let visualSprite: SKSpriteNode?
    private let facingIndicator: SKShapeNode
    private let idleTextures: [SKTexture]
    private let runTextures: [SKTexture]
    private let hitTextures: [SKTexture]
    private let deathTextures: [SKTexture]

    /// A small overlay that plays the active weapon's _Shoot animation once
    /// per shot, then hides again. Textures are cached per WeaponType so
    /// rapid-fire weapons (LMG at ~12 shots/sec) never re-decode the sheet
    /// from disk on every shot.
    private let weaponVisual: SKSpriteNode = {
        let sprite = SKSpriteNode()
        sprite.size = CGSize(width: Balance.weaponFrameSize, height: Balance.weaponFrameSize)
        sprite.position = CGPoint(x: 0, y: Balance.playerRadius * 0.5)
        sprite.zPosition = 1
        sprite.isHidden = true
        return sprite
    }()
    private var weaponShootTextureCache: [WeaponType: [SKTexture]] = [:]

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

        let assetPath = "Assets/Characters/Player"
        func sheet(_ name: String, frameCount: Int) -> SpriteSheetFrames {
            SpriteSheetFrames(sheetName: name, frameSize: Balance.characterFrameSize, frameCount: frameCount, subdirectory: assetPath)
        }
        idleTextures = AssetProvider.loadSpriteSheetTextures(sheet("idle", frameCount: Balance.characterIdleFrameCount)) ?? []
        runTextures = AssetProvider.loadSpriteSheetTextures(sheet("run", frameCount: Balance.characterRunFrameCount)) ?? []
        hitTextures = AssetProvider.loadSpriteSheetTextures(sheet("hit", frameCount: Balance.characterHitFrameCount)) ?? []
        deathTextures = AssetProvider.loadSpriteSheetTextures(sheet("death", frameCount: Balance.characterDeathFrameCount)) ?? []

        if let first = idleTextures.first {
            let sprite = SKSpriteNode(texture: first)
            sprite.size = CGSize(width: Balance.playerRadius * 2, height: Balance.playerRadius * 2)
            visualSprite = sprite
        } else {
            visualSprite = nil
        }

        facingIndicator = SKShapeNode(rectOf: CGSize(width: 6, height: Balance.playerRadius))
        facingIndicator.fillColor = .white
        facingIndicator.strokeColor = .clear
        facingIndicator.position = CGPoint(x: 0, y: Balance.playerRadius * 0.6)

        super.init()
        name = "player"
        zPosition = 100
        if let visualSprite {
            addChild(visualSprite)
        } else {
            addChild(AssetProvider.makeNode(for: .player, radius: Balance.playerRadius, fillColor: .systemGreen))
        }
        addChild(facingIndicator)
        addChild(weaponVisual)
        playAnimation(.idle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
        guard isAlive else { return } // death animation is triggered separately via playDeathAnimation()
        playAnimation(.hit)
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

    func move(by vector: CGVector, deltaTime: TimeInterval, bounds: CGRect) {
        guard !vector.isZero else {
            playAnimation(.idle)
            return
        }
        let dx = vector.dx * moveSpeed * CGFloat(deltaTime)
        let dy = vector.dy * moveSpeed * CGFloat(deltaTime)
        var newPosition = CGPoint(x: position.x + dx, y: position.y + dy)
        newPosition.x = min(max(newPosition.x, bounds.minX + Balance.playerRadius), bounds.maxX - Balance.playerRadius)
        newPosition.y = min(max(newPosition.y, bounds.minY + Balance.playerRadius), bounds.maxY - Balance.playerRadius)
        position = newPosition
        playAnimation(.run)
    }

    func setFacing(angle: CGFloat) {
        facingAngle = angle
        zRotation = angle - .pi / 2
    }

    /// Plays the given weapon's _Shoot animation once, on top of whatever
    /// body animation is currently running. Silently does nothing if the
    /// sheet fails to load (no muzzle overlay, gameplay unaffected).
    func playShootAnimation(for weaponType: WeaponType) {
        guard let textures = shootTextures(for: weaponType) else { return }
        weaponVisual.texture = textures.first
        weaponVisual.isHidden = false
        let animate = SKAction.animate(with: textures, timePerFrame: Balance.weaponShootFrameTime)
        weaponVisual.run(.sequence([animate, .run { [weak self] in self?.weaponVisual.isHidden = true }]), withKey: "shoot")
    }

    private func shootTextures(for weaponType: WeaponType) -> [SKTexture]? {
        if let cached = weaponShootTextureCache[weaponType] { return cached }
        guard let textures = AssetProvider.loadSpriteSheetTextures(weaponType.shootSheet), !textures.isEmpty else { return nil }
        weaponShootTextureCache[weaponType] = textures
        return textures
    }

    /// Plays the real death animation in place (the node itself is never
    /// removed — GameScene keeps `player` around for the Game Over overlay
    /// and health readouts). Falls back to a scale+fade if Player_Death
    /// frames failed to load, matching Walker's fallback behavior.
    func playDeathAnimation() {
        guard let visualSprite else { return }
        visualSprite.removeAllActions()
        if !deathTextures.isEmpty {
            visualSprite.run(.animate(with: deathTextures, timePerFrame: Balance.characterDeathFrameTime))
        } else {
            visualSprite.run(.group([
                .scale(to: 0.4, duration: Balance.zombieDeathEffectDuration),
                .fadeOut(withDuration: Balance.zombieDeathEffectDuration)
            ]))
        }
    }

    private var isPlayingReactionAnimation: Bool {
        currentAnimState == .hit && visualSprite?.action(forKey: "anim") != nil
    }

    private func playAnimation(_ state: AnimState) {
        guard let visualSprite, isAlive else { return }
        guard !isPlayingReactionAnimation else { return }
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
        }
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
