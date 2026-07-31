import Foundation

/// Abstracts audio playback so SettingsScene and gameplay code have a real
/// hook to call today, and a real engine (AVAudioEngine, SKAudioNode, etc.)
/// can be dropped in behind this protocol later without touching any call
/// site. No audio assets exist in this project yet.
protocol AudioManager: AnyObject {
    func playSFX(_ name: String)
    func setMasterVolume(_ volume: Float)
    func setSFXVolume(_ volume: Float)
    func setMuted(_ muted: Bool)
}

/// No-op implementation: every call is wired up and reachable end-to-end
/// (Settings sliders/toggle persist to SettingsStore *and* call through
/// here), but nothing actually plays, because there is nothing to play yet.
/// This is intentionally not "fake" — it does not pretend to play a sound,
/// it just silently accepts the call.
final class StubAudioManager: AudioManager {
    func playSFX(_ name: String) {}
    func setMasterVolume(_ volume: Float) {}
    func setSFXVolume(_ volume: Float) {}
    func setMuted(_ muted: Bool) {}
}

/// Swappable global access point. Replace `shared` at app startup once a
/// real implementation exists; nothing else in the codebase needs to change.
enum AudioManagerProvider {
    static var shared: AudioManager = StubAudioManager()
}
