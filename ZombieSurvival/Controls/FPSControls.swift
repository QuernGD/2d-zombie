import SpriteKit
import UIKit

/// First-person touch controls, replacing the top-down build's dual-stick
/// and single-stick+auto-aim schemes entirely.
///
///  - **Left half**: floating virtual joystick. Y drives forward/back, X
///    strafes — both relative to where the player is facing.
///  - **Right half**: drag anywhere (that isn't a button) to turn. There is
///    no true vertical look; a raycaster can't pitch, so vertical drag is
///    ignored rather than faked badly.
///  - **Buttons**: fire (hold to keep firing), reload, weapon swap.
final class FPSControls {
    static let fireButtonName = "fpsFireButton"
    static let reloadButtonName = "fpsReloadButton"
    static let swapButtonName = "fpsSwapButton"

    /// x = strafe (+right), y = forward (+forward), each -1...1.
    private(set) var movement: CGVector = .zero
    /// Radians to turn this frame. Read once per frame via `consumeLookDelta`.
    private var pendingLook: CGFloat = 0
    private(set) var isFiring: Bool = false

    var lookSensitivity: CGFloat = 1.0

    private var moveStick: VirtualJoystick!
    private var lookTouch: UITouch?
    private var lastLookLocation: CGPoint = .zero
    private var fireTouch: UITouch?

    private var fireButton: SKShapeNode?
    private var swapButton: SKShapeNode?

    private weak var layer: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Install

    func install(in layer: SKNode, sceneSize: CGSize) {
        self.layer = layer
        self.sceneSize = sceneSize

        moveStick = VirtualJoystick(radius: Balance.joystickRadius, baseColor: .cyan, knobColor: .white)
        layer.addChild(moveStick)

        let fire = makeButton(text: "FIRE", name: Self.fireButtonName, size: CGSize(width: 108, height: 108), corner: 54)
        fire.position = CGPoint(x: sceneSize.width / 2 - 84, y: -sceneSize.height / 2 + 84)
        layer.addChild(fire)
        fireButton = fire

        let reload = makeButton(text: "RELOAD", name: Self.reloadButtonName, size: CGSize(width: 92, height: 44), corner: 10)
        reload.position = CGPoint(x: sceneSize.width / 2 - 60, y: -sceneSize.height / 2 + 168)
        layer.addChild(reload)

        let swap = makeButton(text: "SWAP", name: Self.swapButtonName, size: CGSize(width: 92, height: 44), corner: 10)
        swap.position = CGPoint(x: sceneSize.width / 2 - 60, y: -sceneSize.height / 2 + 220)
        layer.addChild(swap)
        swapButton = swap

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.text = "MOVE"
        hint.fontSize = 12
        hint.fontColor = SKColor.white.withAlphaComponent(0.30)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: -sceneSize.width / 4, y: -sceneSize.height / 2 + 22)
        layer.addChild(hint)

        let lookHint = SKLabelNode(fontNamed: "Menlo-Bold")
        lookHint.text = "DRAG TO LOOK"
        lookHint.fontSize = 12
        lookHint.fontColor = SKColor.white.withAlphaComponent(0.30)
        lookHint.verticalAlignmentMode = .center
        lookHint.position = CGPoint(x: sceneSize.width / 5, y: -sceneSize.height / 2 + 22)
        layer.addChild(lookHint)
    }

    func setSwapButtonVisible(_ visible: Bool) {
        swapButton?.isHidden = !visible
    }

    /// Turn accumulated since the last call, then reset. Consuming rather
    /// than sampling keeps turn rate tied to actual finger distance instead
    /// of frame rate.
    func consumeLookDelta() -> CGFloat {
        let delta = pendingLook
        pendingLook = 0
        return delta
    }

    // MARK: - Touches

    /// Returns the name of a UI button the touch landed on, if any, so
    /// GameScene can handle taps (reload/swap/HUD) without this class
    /// knowing what they do.
    func touchesBegan(_ touches: Set<UITouch>, scene: SKScene) -> [String] {
        var hitButtons: [String] = []
        for touch in touches {
            let point = touch.location(in: scene)
            let name = scene.atPoint(point).name

            if name == Self.fireButtonName {
                fireTouch = touch
                isFiring = true
                continue
            }
            if let name, !name.isEmpty {
                hitButtons.append(name)
                continue
            }
            if point.x < 0 {
                if moveStick.trackedTouch == nil { moveStick.activate(at: point, touch: touch) }
            } else if lookTouch == nil {
                lookTouch = touch
                lastLookLocation = point
            }
        }
        return hitButtons
    }

    func touchesMoved(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches {
            let point = touch.location(in: scene)
            if touch == moveStick.trackedTouch {
                moveStick.drag(to: point)
            } else if touch == lookTouch {
                pendingLook -= (point.x - lastLookLocation.x)
                    * RaycasterConfig.baseLookRadiansPerPoint * lookSensitivity
                lastLookLocation = point
            }
        }
        movement = moveStick.vector
    }

    func touchesEnded(_ touches: Set<UITouch>, scene: SKScene) {
        for touch in touches {
            if touch == moveStick.trackedTouch { moveStick.release() }
            if touch == lookTouch { lookTouch = nil }
            if touch == fireTouch {
                fireTouch = nil
                isFiring = false
            }
        }
        movement = moveStick.vector
    }

    func touchesCancelled(_ touches: Set<UITouch>, scene: SKScene) {
        touchesEnded(touches, scene: scene)
    }

    /// Called when the scene is paused/resumed so a finger lifted while the
    /// shop was open doesn't leave the player running forever.
    func resetInputState() {
        moveStick?.release()
        movement = .zero
        pendingLook = 0
        lookTouch = nil
        fireTouch = nil
        isFiring = false
    }

    // MARK: - Helpers

    private func makeButton(text: String, name: String, size: CGSize, corner: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: corner)
        button.fillColor = SKColor.darkGray.withAlphaComponent(0.55)
        button.strokeColor = SKColor.white.withAlphaComponent(0.7)
        button.lineWidth = 2
        button.name = name
        button.zPosition = 1000

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        button.addChild(label)
        return button
    }
}
