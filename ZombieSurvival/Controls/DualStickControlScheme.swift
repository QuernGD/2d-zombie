import SpriteKit
import UIKit

/// Twin virtual joysticks: left half of the screen walks/runs the player,
/// right half is a shoot control — aims wherever it's dragged (no target
/// required) and fires continuously while held, faster taps/holds firing
/// as fast as the equipped weapon's fire rate allows. Both float (appear
/// wherever first touched) rather than sitting at a fixed spot, so a
/// static "MOVE"/"FIRE" legend is drawn at the bottom of each half to make
/// each side's purpose clear before the player's first touch.
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

        layer.addChild(makeHintLabel("MOVE", x: -sceneSize.width / 4, sceneSize: sceneSize))
        layer.addChild(makeHintLabel("FIRE", x: sceneSize.width / 4, sceneSize: sceneSize))
    }

    private func makeHintLabel(_ text: String, x: CGFloat, sceneSize: CGSize) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 13
        label.fontColor = SKColor.white.withAlphaComponent(0.35)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: x, y: -sceneSize.height / 2 + 24)
        label.zPosition = 999
        return label
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
