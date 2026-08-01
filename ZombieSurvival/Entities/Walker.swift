import SpriteKit

/// The one enemy type, now drawn as a camera-facing billboard rather than a
/// top-down sprite.
///
/// Two things changed for first person, everything else carried over:
///  - Animation is advanced manually against the scene's delta time instead
///    of by SKActions, because the node is never in the scene graph — the
///    renderer just asks for `currentTexture` each frame and draws it as a
///    billboard. This also makes the frame the renderer sees unambiguous.
///  - Textures are cached per variant across all instances. The old code
///    re-decoded five PNGs on every single spawn, which is fine at 1 spawn
///    a second in 2D and not fine with 25 concurrent zombies.
///
/// It's still an SKNode purely because `Enemy.node` is what WaveManager
/// uses as an identity token, and WaveManager carries over untouched.
final class Walker: SKNode, Enemy {
    var node: SKNode { self }

    private(set) var health: CGFloat
    let maxHealth: CGFloat
    let moveSpeed: CGFloat = Balance.zombieMoveSpeed
    let contactDamage: CGFloat
    let attackCooldown: TimeInterval = Balance.zombieAttackCooldown
    let zombieVariant: Int

    private var lastAttackTime: TimeInterval = -.infinity

    fileprivate enum AnimState { case idle, run, hit, knocked, death }
    private var animState: AnimState = .idle
    private var frameIndex: Int = 0
    private var frameTimer: TimeInterval = 0
    private var animationFinished = false

    private let textures: VariantTextures

    var isAlive: Bool { health > 0 }
    /// True once the death animation has played through, so GameScene knows
    /// it can stop drawing this billboard and drop the reference.
    var isDeathAnimationFinished: Bool { animState == .death && animationFinished }

    /// The frame the billboard renderer should draw right now.
    var currentTexture: SKTexture? {
        let frames = textures.frames(for: animState)
        guard !frames.isEmpty else { return nil }
        return frames[min(frameIndex, frames.count - 1)]
    }

    init(health: CGFloat, contactDamage: CGFloat = Balance.zombieContactDamage, zombieVariant: Int = Int.random(in: 1...4)) {
        self.health = health
        self.maxHealth = health
        self.contactDamage = contactDamage
        self.zombieVariant = zombieVariant
        self.textures = VariantTextures.shared(forVariant: zombieVariant)
        super.init()
        name = "walker"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Update

    func update(
        currentTime: TimeInterval,
        deltaTime: TimeInterval,
        playerPosition: CGPoint,
        solidRects: [CGRect],
        navGrid: NavGrid?
    ) {
        advanceAnimation(deltaTime: deltaTime)
        guard isAlive else { return }
        // Hit/knocked reactions are brief hit-stun: hold position while they play.
        guard !isPlayingReaction else { return }

        let toPlayer = CGVector(dx: playerPosition.x - position.x, dy: playerPosition.y - position.y)
        guard toPlayer.length > 1 else {
            play(.idle)
            return
        }

        // Flow-field pathfinding carries over from the top-down build
        // unchanged — only the rendering became first person.
        var direction = toPlayer.normalized
        if let navGrid,
           !navGrid.hasLineOfSight(from: position, to: playerPosition),
           let routed = navGrid.flowDirection(at: position) {
            direction = routed
        }

        let step = moveSpeed * CGFloat(deltaTime)
        let attempted = CGPoint(x: position.x + direction.dx * step, y: position.y + direction.dy * step)
        position = resolveCollision(from: position, to: attempted, radius: Balance.zombieRadius, solidRects: solidRects)
        play(.run)
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
        guard isAlive else { return }
        play(amount >= Balance.zombieKnockedDamageThreshold ? .knocked : .hit)
    }

    func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    func registerAttack(at time: TimeInterval) {
        lastAttackTime = time
    }

    /// Starts the death animation. GameScene keeps drawing this walker
    /// until `isDeathAnimationFinished`, then drops it.
    func startDeathAnimation() {
        guard !textures.frames(for: .death).isEmpty else {
            // No death art for this variant — treat it as already finished
            // so GameScene drops the billboard instead of leaking it.
            animState = .death
            animationFinished = true
            return
        }
        play(.death, force: true)
    }

    // MARK: - Animation

    private var isPlayingReaction: Bool {
        (animState == .hit || animState == .knocked) && !animationFinished
    }

    private func play(_ state: AnimState, force: Bool = false) {
        guard force || state != animState else { return }
        guard !textures.frames(for: state).isEmpty else { return }
        // Never interrupt death.
        if animState == .death && !force { return }
        animState = state
        frameIndex = 0
        frameTimer = 0
        animationFinished = false
    }

    private func advanceAnimation(deltaTime: TimeInterval) {
        guard !animationFinished else { return }
        let frames = textures.frames(for: animState)
        guard !frames.isEmpty else {
            animationFinished = true
            return
        }
        // A single-frame non-looping state is finished the moment it starts.
        guard frames.count > 1 else {
            if !VariantTextures.loops(animState) { animationFinished = true }
            return
        }

        frameTimer += deltaTime
        let perFrame = VariantTextures.frameDuration(for: animState)
        while frameTimer >= perFrame {
            frameTimer -= perFrame
            frameIndex += 1
            if frameIndex >= frames.count {
                if VariantTextures.loops(animState) {
                    frameIndex = 0
                } else {
                    frameIndex = frames.count - 1
                    animationFinished = true
                    // A finished hit/knocked flinch falls back to idle so
                    // the walker can move again next frame.
                    if animState == .hit || animState == .knocked {
                        animState = .idle
                        frameIndex = 0
                        animationFinished = false
                    }
                    return
                }
            }
        }
    }

    /// Per-variant texture sets, loaded once and shared by every instance.
    fileprivate final class VariantTextures {
        private static var cache: [Int: VariantTextures] = [:]

        let idle: [SKTexture]
        let run: [SKTexture]
        let hit: [SKTexture]
        let knocked: [SKTexture]
        let death: [SKTexture]

        static func shared(forVariant variant: Int) -> VariantTextures {
            if let cached = cache[variant] { return cached }
            let created = VariantTextures(variant: variant)
            cache[variant] = created
            return created
        }

        private init(variant: Int) {
            let path = "Assets/Characters/Zombie\(variant)"
            func load(_ name: String, _ count: Int) -> [SKTexture] {
                AssetProvider.loadSpriteSheetTextures(
                    SpriteSheetFrames(
                        sheetName: name, frameSize: Balance.characterFrameSize,
                        frameCount: count, subdirectory: path
                    )
                ) ?? []
            }
            idle = load("idle", Balance.characterIdleFrameCount)
            run = load("run", Balance.characterRunFrameCount)
            hit = load("hit", Balance.characterHitFrameCount)
            knocked = load("knocked", Balance.characterKnockedFrameCount)
            // Zombie1/2 ship two death variants, Zombie3/4 only one.
            let preferred = load("death2", Balance.characterDeathFrameCount)
            death = preferred.isEmpty ? load("death1", Balance.characterDeathFrameCount) : preferred
        }

        func frames(for state: AnimState) -> [SKTexture] {
            switch state {
            case .idle: return idle
            case .run: return run
            case .hit: return hit
            case .knocked: return knocked
            case .death: return death
            }
        }

        static func frameDuration(for state: AnimState) -> TimeInterval {
            switch state {
            case .idle: return Balance.characterIdleFrameTime
            case .run: return Balance.characterRunFrameTime
            case .hit: return Balance.characterHitFrameTime
            case .knocked: return Balance.characterKnockedFrameTime
            case .death: return Balance.characterDeathFrameTime
            }
        }

        static func loops(_ state: AnimState) -> Bool {
            switch state {
            case .idle, .run: return true
            case .hit, .knocked, .death: return false
            }
        }
    }
}
