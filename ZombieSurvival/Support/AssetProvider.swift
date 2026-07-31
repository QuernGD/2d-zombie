import SpriteKit
import UIKit

/// Every visual kind the game can render. Add new cases here as new entity
/// types are introduced instead of scattering asset lookups elsewhere.
enum EntityVisualKind: String {
    case player
    case walker
    case bullet
    case coin
}

/// Describes a numbered frame sequence on disk: "skeleton-idle" + count 17
/// means skeleton-idle_0 ... skeleton-idle_16. `subdirectory`, if set, is
/// the path (relative to the bundle root) the frames live under — see the
/// note on resolveImage below for why this matters.
struct AnimationFrameSequence {
    let baseName: String
    let count: Int
    let timePerFrame: TimeInterval
    let subdirectory: String?

    init(baseName: String, count: Int, timePerFrame: TimeInterval = 0.08, subdirectory: String? = nil) {
        self.baseName = baseName
        self.count = count
        self.timePerFrame = timePerFrame
        self.subdirectory = subdirectory
    }
}

/// Centralized, swappable node factory. Today every kind falls back to a
/// placeholder colored shape. Drop a texture into Assets.xcassets (bare
/// name lookup) or the Assets/ folder reference (see resolveImage) whose
/// name matches the case's rawValue (e.g. "player", "walker", "bullet",
/// "coin") and this factory starts handing out real sprites automatically
/// — no call sites need to change. The same applies to numbered animation
/// frames via makeAnimatedNode/loadTextures.
enum AssetProvider {
    static func makeNode(for kind: EntityVisualKind, radius: CGFloat, fillColor: SKColor) -> SKNode {
        if let image = resolveImage(named: kind.rawValue, subdirectory: "Assets") {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = CGSize(width: radius * 2, height: radius * 2)
            return sprite
        }
        return makePlaceholder(radius: radius, fillColor: fillColor)
    }

    /// Loads a numbered frame sequence as textures. Returns nil (rather than
    /// a partial array) if any frame is missing, so callers can cleanly fall
    /// back to a placeholder instead of animating through blank frames.
    static func loadTextures(_ frames: AnimationFrameSequence) -> [SKTexture]? {
        var textures: [SKTexture] = []
        textures.reserveCapacity(frames.count)
        for index in 0..<frames.count {
            let name = "\(frames.baseName)_\(index)"
            guard let image = resolveImage(named: name, subdirectory: frames.subdirectory) else { return nil }
            textures.append(SKTexture(image: image))
        }
        return textures
    }

    /// Builds a sprite running a repeating animation from a numbered frame
    /// sequence. Falls back to the same static placeholder shape used by
    /// makeNode if the frames aren't present yet.
    static func makeAnimatedNode(for kind: EntityVisualKind, frames: AnimationFrameSequence, radius: CGFloat, fillColor: SKColor = .white) -> SKNode {
        guard let textures = loadTextures(frames), let first = textures.first else {
            return makePlaceholder(radius: radius, fillColor: fillColor)
        }
        let sprite = SKSpriteNode(texture: first)
        sprite.size = CGSize(width: radius * 2, height: radius * 2)
        sprite.run(.repeatForever(.animate(with: textures, timePerFrame: frames.timePerFrame)), withKey: "animation")
        return sprite
    }

    /// `UIImage(named:)` only checks the bundle root and compiled asset
    /// catalogs (Assets.xcassets) — it does NOT recursively search
    /// subdirectories. Xcode "folder references" (like our Assets/ folder)
    /// preserve their on-disk directory structure inside the app bundle
    /// instead of flattening it, so a file at
    /// ZombieSurvival/Assets/Enemies/Zombie/foo.png ends up at
    /// <bundle>/Assets/Enemies/Zombie/foo.png — invisible to a bare
    /// `UIImage(named: "foo")` lookup. We look it up by explicit bundle
    /// path first and only fall back to the bare `named:` lookup, which
    /// covers Assets.xcassets entries (those have no filesystem path/
    /// subdirectory concept, so the explicit-path lookup can't apply there).
    private static func resolveImage(named name: String, subdirectory: String?) -> UIImage? {
        if let subdirectory,
           let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: name)
    }

    private static func makePlaceholder(radius: CGFloat, fillColor: SKColor) -> SKShapeNode {
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = fillColor
        shape.strokeColor = .white
        shape.lineWidth = 2
        return shape
    }
}
