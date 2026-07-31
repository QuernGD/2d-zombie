import SpriteKit
import UIKit

/// Twin virtual joysticks: left half of the screen moves, right half
/// aims and fires continuously while held.
final class DualStickControlScheme: ControlScheme {
    let type: ControlSchemeType = .dualStick

    private var moveStick: VirtualJoystick!
    private var aimStick: VirtualJoystick!

    var movementVector: CGVector { moveStick?.vector ?? .zero }
    var aimVector: CGVector { aimStick?.vector ?? .zero }
    var isFiring: Bool { aimStick?.isActive ?? false }

    func install(in layer: SKNode, sceneSize: CGSize) {
        moveStick = VirtualJoystick(radius: Balance.joystickRadius, baseColor: .cyan, knobColor: .white)
        aimStick = VirtualJoystick(radius: Balance.joystickRadius, baseColor: .systemRed, knobColor: .white)
        layer.addChild(moveStick)
        layer.addChild(aimStick)
    }

    func touchesBegan(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches {
            let point = touch.location(in: scene)
            if point.x < 0 {
                if moveStick.trackedTouch == nil {
                    moveStick.activate(at: point, touch: touch)
                }
            } else {
                if aimStick.trackedTouch == nil {
                    aimStick.activate(at: point, touch: touch)
                }
            }
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches {
            let point = touch.location(in: scene)
            if touch == moveStick.trackedTouch {
                moveStick.drag(to: point)
            } else if touch == aimStick.trackedTouch {
                aimStick.drag(to: point)
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches {
            if touch == moveStick.trackedTouch {
                moveStick.release()
            }
            if touch == aimStick.trackedTouch {
                aimStick.release()
            }
        }
    }

    func touchesCancelled(_ touches: Set<UITouch>, scene: SKScene) {
        touchesEnded(touches, scene: scene)
    }

    func update(currentTime: TimeInterval, playerPosition: CGPoint, nearestEnemyProvider: () -> CGPoint?) {
        // Fully manual: nothing to derive each frame.
    }
}
