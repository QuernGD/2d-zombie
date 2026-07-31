import SpriteKit
import UIKit

/// A floating virtual joystick: invisible until touched, then appears
/// centered on the touch-down point and tracks drag relative to that point.
final class VirtualJoystick: SKNode {
    let radius: CGFloat
    private(set) var vector: CGVector = .zero
    private(set) var trackedTouch: UITouch?

    private let base: SKShapeNode
    private let knob: SKShapeNode

    var isActive: Bool { trackedTouch != nil }

    init(radius: CGFloat, baseColor: SKColor, knobColor: SKColor) {
        self.radius = radius

        base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = baseColor.withAlphaComponent(0.20)
        base.strokeColor = baseColor.withAlphaComponent(0.55)
        base.lineWidth = 2

        knob = SKShapeNode(circleOfRadius: radius * 0.45)
        knob.fillColor = knobColor.withAlphaComponent(0.85)
        knob.strokeColor = .white
        knob.lineWidth = 1

        super.init()
        zPosition = 1000
        alpha = 0
        addChild(base)
        addChild(knob)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func activate(at point: CGPoint, touch: UITouch) {
        position = point
        trackedTouch = touch
        knob.position = .zero
        vector = .zero
        removeAllActions()
        run(.fadeIn(withDuration: 0.08))
    }

    func drag(to point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        let clampedDist = min(dist, radius)
        let angle = atan2(dy, dx)
        knob.position = CGPoint(x: cos(angle) * clampedDist, y: sin(angle) * clampedDist)
        vector = dist > 0.0001
            ? CGVector(dx: cos(angle) * (clampedDist / radius), dy: sin(angle) * (clampedDist / radius))
            : .zero
    }

    func release() {
        trackedTouch = nil
        vector = .zero
        removeAllActions()
        run(.fadeOut(withDuration: 0.12))
    }
}
