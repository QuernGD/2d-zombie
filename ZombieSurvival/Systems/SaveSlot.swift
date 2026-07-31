import Foundation

/// Lightweight, cheap-to-read summary of what's in a save slot. Kept as its
/// own small file/struct, separate from the full GameState, so LoadGameScene
/// can list all 3 slots without deserializing (and reconstructing) a full
/// run just to show "Round 7, 4,250 coins, 2 hours ago."
struct SaveSlot: Codable {
    let round: Int
    let coins: Int
    let savedAt: Date
}
