import SpriteKit
import UIKit

/// Every visual kind the game can render. Add new cases here as new entity
/// types are introduced instead of scattering asset lookups elsewhere.
enum EntityVisualKind: String {
    case player
    case walker
    case bullet
}

/// Centralized, swappable node factory. Today every kind falls back to a
/// placeholder colored shape. Drop a texture into Assets.xcassets whose name
/// matches the case's rawValue (e.g. "player", "walker", "bullet") and this
/// factory starts handing out real sprites automatically — no call sites
/// need to change.
enum AssetProvider {
    static func makeNode(for kind: EntityVisualKind, radius: CGFloat, fillColor: SKColor) -> SKNode {
        if UIImage(named: kind.rawValue) != nil {
            let sprite = SKSpriteNode(imageNamed: kind.rawValue)
            sprite.size = CGSize(width: radius * 2, height: radius * 2)
            return sprite
        }
        return makePlaceholder(radius: radius, fillColor: fillColor)
    }

    private static func makePlaceholder(radius: CGFloat, fillColor: SKColor) -> SKShapeNode {
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = fillColor
        shape.strokeColor = .white
        shape.lineWidth = 2
        return shape
    }
}
