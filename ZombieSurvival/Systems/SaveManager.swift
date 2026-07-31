import Foundation

/// Manual-save-only persistence: 3 slots, one JSON file for the full
/// GameState per slot plus a separate lightweight SaveSlot summary file so
/// LoadGameScene can list slots without deserializing full runs. Lives in
/// the Documents directory via FileManager — never UserDefaults, which is
/// reserved for global settings (see SettingsStore). There is no autosave
/// anywhere in this codebase; every write here traces back to an explicit
/// "Save Game" tap.
enum SaveManager {
    static let slotCount = 3

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func stateURL(forSlot slot: Int) -> URL {
        documentsDirectory.appendingPathComponent("save_slot_\(slot).json")
    }

    private static func summaryURL(forSlot slot: Int) -> URL {
        documentsDirectory.appendingPathComponent("save_slot_\(slot)_summary.json")
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Writes both the full state and its lightweight summary. Best-effort:
    /// a failed write (e.g. disk full) is silently dropped rather than
    /// crashing the run — there's nothing else useful to do with it mid-game.
    @discardableResult
    static func save(_ state: GameState, toSlot slot: Int) -> Bool {
        guard (0..<slotCount).contains(slot) else { return false }
        do {
            let stateData = try encoder.encode(state)
            try stateData.write(to: stateURL(forSlot: slot), options: .atomic)

            let summary = SaveSlot(round: state.round, coins: state.coins, savedAt: Date())
            let summaryData = try encoder.encode(summary)
            try summaryData.write(to: summaryURL(forSlot: slot), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func loadState(fromSlot slot: Int) -> GameState? {
        guard (0..<slotCount).contains(slot), let data = try? Data(contentsOf: stateURL(forSlot: slot)) else { return nil }
        return try? decoder.decode(GameState.self, from: data)
    }

    /// nil means the slot is empty ("Empty" in LoadGameScene).
    static func summary(forSlot slot: Int) -> SaveSlot? {
        guard (0..<slotCount).contains(slot), let data = try? Data(contentsOf: summaryURL(forSlot: slot)) else { return nil }
        return try? decoder.decode(SaveSlot.self, from: data)
    }

    /// The slot with the most recent `savedAt`, or nil if every slot is empty.
    static func mostRecentSlot() -> Int? {
        var best: (slot: Int, date: Date)?
        for slot in 0..<slotCount {
            guard let summary = summary(forSlot: slot) else { continue }
            if best == nil || summary.savedAt > best!.date {
                best = (slot, summary.savedAt)
            }
        }
        return best?.slot
    }

    static func hasAnySave() -> Bool {
        mostRecentSlot() != nil
    }
}
