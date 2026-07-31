import SpriteKit

/// One-time, run-persistent upgrades bought in the shop. Each is a flat
/// boolean the player either owns or doesn't — no stacking, no tiers.
enum Perk: String, Codable, CaseIterable {
    case vitality
    case rapidHands
    case overdrive
    case sprinter

    var displayName: String {
        switch self {
        case .vitality: return "Vitality"
        case .rapidHands: return "Rapid Hands"
        case .overdrive: return "Overdrive"
        case .sprinter: return "Sprinter"
        }
    }

    var summary: String {
        switch self {
        case .vitality: return "+100% Max Health"
        case .rapidHands: return "50% Faster Reload"
        case .overdrive: return "+25% Fire Rate"
        case .sprinter: return "+20% Move Speed"
        }
    }

    var cost: Int { Balance.perkCost }

    /// Used for the HUD icon and shop row — placeholder styling like
    /// everything else until real art exists.
    var iconColor: SKColor {
        switch self {
        case .vitality: return .systemRed
        case .rapidHands: return .systemOrange
        case .overdrive: return .systemPurple
        case .sprinter: return .systemTeal
        }
    }

    var iconInitial: String {
        switch self {
        case .vitality: return "V"
        case .rapidHands: return "R"
        case .overdrive: return "O"
        case .sprinter: return "S"
        }
    }
}
