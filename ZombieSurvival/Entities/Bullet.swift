import SpriteKit

/// What happens when a bullet connects (or, for AoE, runs out of range).
/// GameScene reads this off the bullet at resolution time; the bullet
/// itself doesn't need to know how to apply damage. Unchanged — every
/// weapon class still declares its behaviour through this.
enum BulletBehavior {
    case standard
    case aoe(radius: CGFloat)
    case chain(maxJumps: Int, jumpRange: CGFloat, falloff: CGFloat)
}

/// A projectile travelling through the world.
///
/// In first person only the **grenade launcher and Arc Cannon** still spawn
/// these — their travel time is the mechanic. Everything else became a
/// hitscan (see HitscanResolver), because a visibly crawling bullet reads
/// as broken when you're aiming down the middle of the screen at something
/// three cells away.
///
/// No longer an SKNode: it lives in map space and is drawn as a billboard
/// like everything else in the world.
final class Bullet {
    /// World position (x right, y up).
    var position: CGPoint
    let velocity: CGVector
    let damage: CGFloat
    let maxRange: CGFloat
    let behavior: BulletBehavior
    private var travelled: CGFloat = 0

    init(position: CGPoint, velocity: CGVector, damage: CGFloat, maxRange: CGFloat, behavior: BulletBehavior = .standard) {
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.maxRange = maxRange
        self.behavior = behavior
    }

    /// Advances the bullet and returns false once it has exceeded its range.
    @discardableResult
    func advance(deltaTime: TimeInterval) -> Bool {
        let dx = velocity.dx * CGFloat(deltaTime)
        let dy = velocity.dy * CGFloat(deltaTime)
        position = CGPoint(x: position.x + dx, y: position.y + dy)
        travelled += sqrt(dx * dx + dy * dy)
        return travelled < maxRange
    }

    /// Shared billboard art for in-flight projectiles — the first frame of
    /// the effects pack's impact sheet, which is the closest thing to a
    /// projectile sprite the pack contains. Loaded once for all bullets.
    static let billboardTexture: SKTexture? = {
        AssetProvider.loadSpriteSheetTextures(
            SpriteSheetFrames(
                sheetName: "bullet_impact",
                frameSize: Balance.bulletImpactFrameSize,
                frameCount: Balance.bulletImpactFrameCount,
                subdirectory: "Assets/Effects"
            )
        )?.first
    }()
}
