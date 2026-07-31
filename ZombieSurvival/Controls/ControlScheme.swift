import SpriteKit
import UIKit

/// Which input mapping is active. Persisted on GameState so a future
/// settings screen can switch this without touching gameplay code.
enum ControlSchemeType: String, Codable, CaseIterable {
    case dualStick
    case singleStickAutoAim
}

/// Abstracts "how the player's intent gets from touches into game state."
/// GameScene talks only to this protocol, so adding new input mappings
/// (single-stick + auto-aim, MFi controller, etc.) never touches GameScene.
protocol ControlScheme: AnyObject {
    var type: ControlSchemeType { get }

    /// Normalized (-1...1 on each axis) movement intent.
    var movementVector: CGVector { get }
    /// Normalized aim direction. Zero when there is no aim target/input.
    var aimVector: CGVector { get }
    /// Whether the player is currently requesting fire.
    var isFiring: Bool { get }

    func install(in layer: SKNode, sceneSize: CGSize)
    func touchesBegan(_ touches: Set<UITouch>, scene: SKScene)
    func touchesMoved(_ touches: Set<UITouch>, scene: SKScene)
    func touchesEnded(_ touches: Set<UITouch>, scene: SKScene)
    func touchesCancelled(_ touches: Set<UITouch>, scene: SKScene)

    /// Called once per frame before movement/aim are read, so schemes that
    /// derive aim automatically (auto-aim) can update themselves.
    func update(currentTime: TimeInterval, playerPosition: CGPoint, nearestEnemyProvider: () -> CGPoint?)
}

enum ControlSchemeFactory {
    static func make(_ type: ControlSchemeType) -> ControlScheme {
        switch type {
        case .dualStick:
            return DualStickControlScheme()
        case .singleStickAutoAim:
            return SingleStickAutoAimControlScheme()
        }
    }
}
