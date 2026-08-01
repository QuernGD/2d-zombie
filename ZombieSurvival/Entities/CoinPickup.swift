import SpriteKit

/// A dropped coin — the Items pack's "Scraps" icon, unchanged from the
/// top-down build. Now a plain world-space entity drawn as a billboard
/// rather than an SKNode in a world layer, with its short idle animation
/// advanced manually (same reason as Walker: nothing is in the scene graph
/// to run SKActions).
///
/// Movement (magnet pull, round-end auto-collect) and the collect decision
/// still live in GameScene's update loop.
final class CoinPickup {
    let value: Int
    var position: CGPoint
    private(set) var isCollected: Bool = false

    private var frameIndex: Int = 0
    private var frameTimer: TimeInterval = 0

    init(value: Int, position: CGPoint) {
        self.value = value
        self.position = position
        // Desynchronise the shared loop so a pile of coins doesn't pulse in
        // lockstep.
        self.frameIndex = Int.random(in: 0..<max(Self.textures.count, 1))
    }

    func markCollected() {
        isCollected = true
    }

    func advanceAnimation(deltaTime: TimeInterval) {
        guard Self.textures.count > 1 else { return }
        frameTimer += deltaTime
        while frameTimer >= Balance.itemFrameTime {
            frameTimer -= Balance.itemFrameTime
            frameIndex = (frameIndex + 1) % Self.textures.count
        }
    }

    var currentTexture: SKTexture? {
        guard !Self.textures.isEmpty else { return nil }
        return Self.textures[min(frameIndex, Self.textures.count - 1)]
    }

    /// Loaded once and shared by every coin.
    static let textures: [SKTexture] = {
        AssetProvider.loadSpriteSheetTextures(
            SpriteSheetFrames(
                sheetName: "coin",
                frameSize: Balance.itemFrameSize,
                frameCount: Balance.itemFrameCount,
                subdirectory: "Assets/Items",
                timePerFrame: Balance.itemFrameTime
            )
        ) ?? []
    }()
}
