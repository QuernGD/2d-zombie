import CoreGraphics
import Foundation

/// Instant-hit weapon resolution.
///
/// In the top-down build every weapon spawned a travelling Bullet. In first
/// person that's wrong for most of them: you can't lead a target you're
/// aiming down the middle of the screen at, and a visible projectile
/// crawling toward a zombie 3 cells away looks broken. So the fast weapons
/// (pistol, SMG, rifle, sniper, LMG — and each shotgun pellet) became
/// hitscans, while the grenade launcher and Arc Cannon stay as real
/// projectiles because their travel time *is* the mechanic.
enum HitscanResolver {

    struct Result {
        /// Nearest enemy struck, if any.
        let enemy: Walker?
        /// Where the ray stopped — an enemy, a wall, or its range limit.
        let impactPoint: CGPoint
        let distance: CGFloat
    }

    /// Casts a single ray. An enemy only counts if it is nearer than the
    /// first wall along the ray, so you can't shoot through geometry.
    static func cast(
        from origin: CGPoint,
        angle: CGFloat,
        maxRange: CGFloat,
        map: MapModel,
        enemies: [Walker]
    ) -> Result {
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let wallDistance = distanceToWall(from: origin, direction: direction, maxRange: maxRange, map: map)

        var nearest: Walker?
        var nearestDistance = wallDistance

        for enemy in enemies where enemy.isAlive {
            let toEnemy = CGVector(dx: enemy.position.x - origin.x, dy: enemy.position.y - origin.y)
            // Distance along the ray to the enemy's closest approach.
            let along = toEnemy.dx * direction.dx + toEnemy.dy * direction.dy
            guard along > 0, along < nearestDistance else { continue }

            let closestX = origin.x + direction.dx * along
            let closestY = origin.y + direction.dy * along
            let perpendicular = hypot(enemy.position.x - closestX, enemy.position.y - closestY)
            guard perpendicular <= Balance.zombieRadius else { continue }

            nearest = enemy
            nearestDistance = along
        }

        let impact = CGPoint(
            x: origin.x + direction.dx * nearestDistance,
            y: origin.y + direction.dy * nearestDistance
        )
        return Result(enemy: nearest, impactPoint: impact, distance: nearestDistance)
    }

    /// Marches the ray in fixed steps until it enters a solid cell. Coarser
    /// than a full DDA, but a step is a fraction of a cell so the error is
    /// far below anything a player could notice, and it keeps this
    /// independent of the renderer's grid-space maths.
    private static func distanceToWall(
        from origin: CGPoint,
        direction: CGVector,
        maxRange: CGFloat,
        map: MapModel
    ) -> CGFloat {
        let step = RaycasterConfig.hitscanWallStep
        var travelled: CGFloat = 0
        while travelled < maxRange {
            travelled += step
            let point = CGPoint(x: origin.x + direction.dx * travelled, y: origin.y + direction.dy * travelled)
            if map.isSolid(atWorld: point) { return travelled - step }
        }
        return maxRange
    }
}
