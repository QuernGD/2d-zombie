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
/// means skeleton-idle_0 ... skeleton-idle_16.
struct AnimationFrameSequence {
    let baseName: String
    let count: Int
    let timePerFrame: TimeInterval

    init(baseName: String, count: Int, timePerFrame: TimeInterval = 0.08) {
        self.baseName = baseName
        self.count = count
        self.timePerFrame = timePerFrame
    }
}

/// Centralized, swappable node factory. Today every kind falls back to a
/// placeholder colored shape. Drop a texture into Assets.xcassets (or the
/// Assets/ folder reference) whose name matches the case's rawValue (e.g.
/// "player", "walker", "bullet", "coin") and this factory starts handing
/// out real sprites automatically — no call sites need to change. The same
/// applies to numbered animation frames via makeAnimatedNode/loadTextures.
enum AssetProvider {
    static func makeNode(for kind: EntityVisualKind, radius: CGFloat, fillColor: SKColor) -> SKNode {
        if UIImage(named: kind.rawValue) != nil {
            let sprite = SKSpriteNode(imageNamed: kind.rawValue)
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
            guard UIImage(named: name) != nil else { return nil }
            textures.append(SKTexture(imageNamed: name))
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

    private static func makePlaceholder(radius: CGFloat, fillColor: SKColor) -> SKShapeNode {
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = fillColor
        shape.strokeColor = .white
        shape.lineWidth = 2
        return shape
    }
}
