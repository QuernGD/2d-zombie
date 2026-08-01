import Foundation

/// Retained only for persistence compatibility.
///
/// The first-person build has a single control scheme (move stick + drag to
/// look, see FPSControls), so the dual-stick / single-stick+auto-aim
/// implementations and the `ControlScheme` protocol they conformed to are
/// gone. This enum stays because `GameState` and `SettingsStore` both
/// persist it, and removing it would make every existing save fail to
/// decode for no gameplay benefit. Nothing reads it any more.
enum ControlSchemeType: String, Codable, CaseIterable {
    case dualStick
    case singleStickAutoAim
}
