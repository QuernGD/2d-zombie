import CoreGraphics
import Foundation

/// How many wall columns the raycaster casts and draws. Fewer columns =
/// fewer SKSpriteNodes touched per frame, which is the single biggest lever
/// on frame time, so this is exposed as a graphics setting.
enum RenderQuality: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }

    /// Target column count. The renderer clamps this to the scene width so
    /// a column is never narrower than a point on small devices.
    var columnCount: Int {
        switch self {
        case .low: return 160
        case .medium: return 240
        case .high: return 320
        }
    }

    /// Vertical slices each enemy billboard is cut into for per-column
    /// depth clipping. More slices = finer occlusion at wall edges, at the
    /// cost of more nodes per visible enemy.
    var billboardSlices: Int {
        switch self {
        case .low: return 6
        case .medium: return 10
        case .high: return 14
        }
    }
}

/// Tuning for the first-person renderer. Deliberately a separate file from
/// Balance.swift: Balance owns *gameplay* numbers (which carry over from
/// the top-down build untouched), this owns *presentation* numbers that
/// only exist because of the raycaster.
enum RaycasterConfig {

    // MARK: - World

    /// Size of one map cell in world units. Player radius (20) and zombie
    /// radius (18) come from Balance unchanged, so at 64 an entity is a
    /// bit over half a cell — comfortable clearance in the 3-cell-wide
    /// corridors the Phase 8 layouts were designed with.
    static let cellSize: CGFloat = 64

    // MARK: - Camera

    /// Horizontal field of view. 66° is the classic Wolfenstein value and
    /// is what the `plane = dir rotated 90° * tan(fov/2)` setup below
    /// assumes looks correct.
    static let fieldOfView: CGFloat = 66 * .pi / 180
    /// Fraction of screen height a unit-height wall fills at 1 cell away.
    static let wallHeightScale: CGFloat = 1.0
    /// Walls closer than this are clamped, so a wall pressed against the
    /// camera doesn't ask SpriteKit for a 40,000pt-tall sprite.
    static let minimumWallDistance: CGFloat = 0.05
    static let maximumColumnHeightMultiplier: CGFloat = 4.0
    /// How far the DDA will step before giving up on a column.
    static let maximumRayDepth: Int = 64

    // MARK: - Shading

    /// Distance (in cells) at which a wall reaches full darkness.
    static let shadingFalloffDistance: CGFloat = 14
    static let maximumShade: CGFloat = 0.82
    /// Extra darkening applied to walls hit on their north/south face, the
    /// cheap trick that makes corners readable without real lighting.
    static let sideFaceShade: CGFloat = 0.18

    static let ceilingColorComponents: (CGFloat, CGFloat, CGFloat) = (0.16, 0.17, 0.20)
    static let floorColorComponents: (CGFloat, CGFloat, CGFloat) = (0.24, 0.21, 0.17)

    // MARK: - Look controls

    /// Radians of turn per point of horizontal drag, before the player's
    /// sensitivity multiplier.
    static let baseLookRadiansPerPoint: CGFloat = 0.005
    /// Sensitivity slider range (multiplies the base rate above).
    static let minimumLookSensitivity: Float = 0.4
    static let maximumLookSensitivity: Float = 2.4
    static let defaultLookSensitivity: Float = 1.0

    // MARK: - Weapons

    /// Hitscan weapons resolve instantly along a ray; only these two keep
    /// travelling through the world.
    static let hitscanImpactFlashDuration: TimeInterval = 0.05
    /// Step size (world units) used when marching a hitscan ray to find the
    /// first wall. Smaller = more precise, more iterations.
    static let hitscanWallStep: CGFloat = 8

    // MARK: - Weapon viewmodel (placeholder art — see README)

    /// Fraction of screen height the weapon sprite occupies.
    static let viewmodelHeightFraction: CGFloat = 0.28
    static let viewmodelBobAmplitude: CGFloat = 6
    static let viewmodelBobFrequency: CGFloat = 7
}
