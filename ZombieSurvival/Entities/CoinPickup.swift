import SpriteKit

/// A dropped coin — visually represented by the Items pack's "Scraps" icon
/// (a grey/silver metal-scrap pile), chosen because the pack has no literal
/// coin icon and Scraps reads more like loose currency than the other item
/// icons (blueprints, meds, etc). The source file is copied into the
/// project as Assets/Items/coin.png. Like every item icon in this pack it's
/// actually a short animated sheet (not a static image), loaded with an
/// explicit subdirectory so it never depends on AssetProvider.makeNode's
/// hardcoded root "Assets" lookup.
///
/// Movement (magnet pull, round-end auto-collect) and the actual collect/
/// despawn decision live in GameScene's update loop — this node just
/// carries its value and a collected flag so GameScene doesn't
/// double-credit the same coin.
final class CoinPickup: SKNode {
    let value: Int
    private(set) var isCollected: Bool = false

    init(value: Int) {
        self.value = value
        super.init()
        zPosition = 60
        name = "coin"

        let sheet = SpriteSheetFrames(
            sheetName: "coin",
            frameSize: Balance.itemFrameSize,
            frameCount: Balance.itemFrameCount,
            subdirectory: "Assets/Items",
            timePerFrame: Balance.itemFrameTime
        )
        addChild(AssetProvider.makeAnimatedNode(sheet: sheet, size: CGSize(width: 20, height: 20), fallbackColor: .systemYellow))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func markCollected() {
        isCollected = true
    }
}
