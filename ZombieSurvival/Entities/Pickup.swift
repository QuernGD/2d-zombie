import SpriteKit

/// The four world pickups. Icons all come from the pack's
/// Items_Sprites_16x16 set via AssetProvider — no new art.
enum PickupType: String, CaseIterable {
    /// Heals a fraction of *current* max health, so it scales with Vitality.
    case medkit
    /// All weapon damage x2 for a short window.
    case doubleDamage
    /// Move speed x1.6 for a short window.
    case speedBoost
    /// Kills every living zombie instantly; each still drops its coins.
    case nuke

    /// Sheet name under Assets/Items.
    var sheetName: String {
        switch self {
        case .medkit: return "medkit"
        case .doubleDamage: return "damage_boost"   // grenades icon
        case .speedBoost: return "speed_boost"      // battery icon
        case .nuke: return "nuke"                   // skull icon
        }
    }

    var hudLabel: String {
        switch self {
        case .medkit: return "MED"
        case .doubleDamage: return "2X DMG"
        case .speedBoost: return "SPEED"
        case .nuke: return "NUKE"
        }
    }

    var hudColor: SKColor {
        switch self {
        case .medkit: return .systemGreen
        case .doubleDamage: return .systemOrange
        case .speedBoost: return .systemBlue
        case .nuke: return .systemRed
        }
    }

    /// Nil for instant-effect pickups (medkit, nuke) — only the two timed
    /// buffs have a duration.
    var duration: TimeInterval? {
        switch self {
        case .medkit, .nuke: return nil
        case .doubleDamage: return Balance.doubleDamageDuration
        case .speedBoost: return Balance.speedBoostDuration
        }
    }

    /// The animated icon frames, loaded once per type and shared.
    var textures: [SKTexture] {
        if let cached = Self.textureCache[self] { return cached }
        let loaded = AssetProvider.loadSpriteSheetTextures(
            SpriteSheetFrames(
                sheetName: sheetName,
                frameSize: Balance.itemFrameSize,
                frameCount: Balance.itemFrameCount,
                subdirectory: "Assets/Items",
                timePerFrame: Balance.itemFrameTime
            )
        ) ?? []
        Self.textureCache[self] = loaded
        return loaded
    }

    private static var textureCache: [PickupType: [SKTexture]] = [:]
}

/// A collectable item sitting on the floor. Same pattern as CoinPickup: a
/// plain world-space entity drawn as a billboard, with collection handled
/// by GameScene's update loop.
///
/// Its lifetime is measured against the scene's `gameClock`, not wall time,
/// so a pickup can't quietly expire while the shop is open.
final class Pickup {
    let type: PickupType
    let position: CGPoint
    /// gameClock value at which this despawns.
    private let expiryClock: TimeInterval
    private(set) var isCollected = false

    private var frameIndex: Int
    private var frameTimer: TimeInterval = 0

    init(type: PickupType, position: CGPoint, spawnClock: TimeInterval) {
        self.type = type
        self.position = position
        self.expiryClock = spawnClock + Balance.pickupLifetime
        self.frameIndex = Int.random(in: 0..<max(type.textures.count, 1))
    }

    func markCollected() { isCollected = true }

    func hasExpired(at clock: TimeInterval) -> Bool { clock >= expiryClock }

    /// Blinks during the last few seconds so an about-to-vanish pickup
    /// reads as a warning rather than just disappearing.
    func alpha(at clock: TimeInterval) -> CGFloat {
        let remaining = expiryClock - clock
        guard remaining <= Balance.pickupFadeWarning else { return 1 }
        // ~4 blinks/sec, never fully invisible so it stays findable.
        return CGFloat(0.35 + 0.65 * abs(sin(remaining * 8)))
    }

    func advanceAnimation(deltaTime: TimeInterval) {
        let frames = type.textures
        guard frames.count > 1 else { return }
        frameTimer += deltaTime
        while frameTimer >= Balance.itemFrameTime {
            frameTimer -= Balance.itemFrameTime
            frameIndex = (frameIndex + 1) % frames.count
        }
    }

    var currentTexture: SKTexture? {
        let frames = type.textures
        guard !frames.isEmpty else { return nil }
        return frames[min(frameIndex, frames.count - 1)]
    }
}
