import CoreGraphics

extension CGVector {
    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var isZero: Bool {
        dx == 0 && dy == 0
    }

    var normalized: CGVector {
        let l = length
        guard l > 0 else { return .zero }
        return CGVector(dx: dx / l, dy: dy / l)
    }
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return sqrt(dx * dx + dy * dy)
}
