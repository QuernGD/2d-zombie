import Foundation
import CoreGraphics

/// Difficulty applies a flat multiplier to zombie health and contact damage.
/// Chosen at run start (Map Select, or the global default from Settings),
/// then baked into that run's GameState and locked — SettingsScene shows it
/// read-only whenever it's opened mid-run.
enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .easy: return Balance.difficultyEasyMultiplier
        case .medium: return Balance.difficultyMediumMultiplier
        case .hard: return Balance.difficultyHardMultiplier
        }
    }
}

enum ParticleDensity: String, Codable, CaseIterable {
    case off
    case low
    case high

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .high: return "High"
        }
    }
}

enum FrameCap: Int, Codable, CaseIterable {
    case thirty = 30
    case sixty = 60

    var displayName: String { "\(rawValue)" }
}

/// Global, cross-run settings — persisted to UserDefaults (never GameState/
/// SaveManager; run data and settings are deliberately separate stores).
/// Read/written by SettingsScene; GameScene reads controlSchemeType and
/// difficulty when starting/resuming a run.
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    private enum Keys {
        static let masterVolume = "settings.masterVolume"
        static let sfxVolume = "settings.sfxVolume"
        static let isMuted = "settings.isMuted"
        static let particleDensity = "settings.particleDensity"
        static let bloodEffectsEnabled = "settings.bloodEffectsEnabled"
        static let screenShakeEnabled = "settings.screenShakeEnabled"
        static let damageNumbersEnabled = "settings.damageNumbersEnabled"
        static let frameCap = "settings.frameCap"
        static let controlSchemeType = "settings.controlSchemeType"
        static let difficulty = "settings.difficulty"
        static let lookSensitivity = "settings.lookSensitivity"
        static let renderQuality = "settings.renderQuality"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var masterVolume: Float {
        get { defaults.object(forKey: Keys.masterVolume) as? Float ?? 1.0 }
        set { defaults.set(newValue, forKey: Keys.masterVolume) }
    }

    var sfxVolume: Float {
        get { defaults.object(forKey: Keys.sfxVolume) as? Float ?? 1.0 }
        set { defaults.set(newValue, forKey: Keys.sfxVolume) }
    }

    var isMuted: Bool {
        get { defaults.bool(forKey: Keys.isMuted) }
        set { defaults.set(newValue, forKey: Keys.isMuted) }
    }

    var particleDensity: ParticleDensity {
        get { ParticleDensity(rawValue: defaults.string(forKey: Keys.particleDensity) ?? "") ?? .high }
        set { defaults.set(newValue.rawValue, forKey: Keys.particleDensity) }
    }

    var bloodEffectsEnabled: Bool {
        get { defaults.object(forKey: Keys.bloodEffectsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.bloodEffectsEnabled) }
    }

    var screenShakeEnabled: Bool {
        get { defaults.object(forKey: Keys.screenShakeEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.screenShakeEnabled) }
    }

    var damageNumbersEnabled: Bool {
        get { defaults.object(forKey: Keys.damageNumbersEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.damageNumbersEnabled) }
    }

    var frameCap: FrameCap {
        get { FrameCap(rawValue: defaults.integer(forKey: Keys.frameCap)) ?? .sixty }
        set { defaults.set(newValue.rawValue, forKey: Keys.frameCap) }
    }

    /// The active default whenever a screen isn't overridden by GameScene's
    /// live control scheme (e.g. before a run starts, or as the base a new
    /// run boots with).
    var controlSchemeType: ControlSchemeType {
        get { ControlSchemeType(rawValue: defaults.string(forKey: Keys.controlSchemeType) ?? "") ?? .dualStick }
        set { defaults.set(newValue.rawValue, forKey: Keys.controlSchemeType) }
    }

    /// The default used when starting a *new* run. A run in progress keeps
    /// whatever difficulty it started with regardless of later changes here.
    var difficulty: Difficulty {
        get { Difficulty(rawValue: defaults.string(forKey: Keys.difficulty) ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Keys.difficulty) }
    }

    // MARK: - First-person settings

    /// Multiplier on drag-to-look turn rate. Applied live — GameScene
    /// re-reads it every time gameplay resumes.
    var lookSensitivity: Float {
        get { defaults.object(forKey: Keys.lookSensitivity) as? Float ?? RaycasterConfig.defaultLookSensitivity }
        set {
            let clamped = min(max(newValue, RaycasterConfig.minimumLookSensitivity), RaycasterConfig.maximumLookSensitivity)
            defaults.set(clamped, forKey: Keys.lookSensitivity)
        }
    }

    /// How many columns the raycaster draws. This is the main performance
    /// dial, which is why it's a player-facing setting rather than a
    /// constant — dropping it is the first thing to try if a device can't
    /// hold 60fps with a full horde on screen.
    var renderQuality: RenderQuality {
        get { RenderQuality(rawValue: defaults.string(forKey: Keys.renderQuality) ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Keys.renderQuality) }
    }
}
