import SpriteKit
import UIKit

/// Single movement stick; aim direction is derived automatically toward the
/// nearest alive enemy each frame, and firing is continuous whenever a
/// target is in range. Not yet exposed in any settings UI (there isn't one
/// yet) — this exists so ControlSchemeFactory can hand it out once a
/// settings screen is built, without any GameScene changes.
final class SingleStickAutoAimControlScheme: ControlScheme {
    let type: ControlSchemeType = .singleStickAutoAim

    private var moveStick: VirtualJoystick!
    private(set) var aimVector: CGVector = .zero
    private(set) var isFiring: Bool = false

    var movementVector: CGVector { moveStick?.vector ?? .zero }

    func install(in layer: SKNode, sceneSize: CGSize) {
        moveStick = VirtualJoystick(radius: Balance.joystickRadius, baseColor: .cyan, knobColor: .white)
        layer.addChild(moveStick)
    }

    func touchesBegan(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches where moveStick.trackedTouch == nil {
            moveStick.activate(at: touch.location(in: scene), touch: touch)
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches where touch == moveStick.trackedTouch {
            moveStick.drag(to: touch.location(in: scene))
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches where touch == moveStick.trackedTouch {
            moveStick.release()
        }
    }

    func touchesCancelled(_ touches: Set<UITouch>, scene: SKScene) {
        touchesEnded(touches, scene: scene)
    }

    func update(currentTime: TimeInterval, playerPosition: CGPoint, nearestEnemyProvider: () -> CGPoint?) {
        guard let target = nearestEnemyProvider() else {
            aimVector = .zero
            isFiring = false
            return
        }
        let toTarget = CGVector(dx: target.x - playerPosition.x, dy: target.y - playerPosition.y)
        aimVector = toTarget.normalized
        isFiring = true
    }
}
