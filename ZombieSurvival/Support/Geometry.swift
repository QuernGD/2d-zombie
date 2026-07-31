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

/// True if a circle at `center` with the given `radius` overlaps any rect
/// in `rects` (closest-point-on-rect test — works whether the center is
/// inside, outside, or exactly on a rect edge).
func circleIntersectsAnyRect(center: CGPoint, radius: CGFloat, rects: [CGRect]) -> Bool {
    for rect in rects {
        let closestX = min(max(center.x, rect.minX), rect.maxX)
        let closestY = min(max(center.y, rect.minY), rect.maxY)
        let dx = center.x - closestX
        let dy = center.y - closestY
        if dx * dx + dy * dy < radius * radius {
            return true
        }
    }
    return false
}

/// Resolves a proposed circular-entity move against a set of solid rects
/// (map walls/obstacles) by trying the full move, then X-only, then
/// Y-only, then giving up and staying put — simple axis-separated
/// collision that lets the player/enemies slide along a wall or obstacle
/// edge instead of just stopping dead on contact.
func resolveCollision(from current: CGPoint, to attempted: CGPoint, radius: CGFloat, solidRects: [CGRect]) -> CGPoint {
    guard !solidRects.isEmpty else { return attempted }
    if !circleIntersectsAnyRect(center: attempted, radius: radius, rects: solidRects) {
        return attempted
    }
    let xOnly = CGPoint(x: attempted.x, y: current.y)
    if !circleIntersectsAnyRect(center: xOnly, radius: radius, rects: solidRects) {
        return xOnly
    }
    let yOnly = CGPoint(x: current.x, y: attempted.y)
    if !circleIntersectsAnyRect(center: yOnly, radius: radius, rects: solidRects) {
        return yOnly
    }
    return current
}
