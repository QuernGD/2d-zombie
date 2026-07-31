import SpriteKit

/// A dropped coin. Movement (magnet pull, round-end auto-collect) and the
/// actual collect/despawn decision live in GameScene's update loop — this
/// node just carries its value and a collected flag so GameScene doesn't
/// double-credit the same coin.
final class CoinPickup: SKNode {
    let value: Int
    private(set) var isCollected: Bool = false

    init(value: Int) {
        self.value = value
        super.init()
        zPosition = 60
        name = "coin"
        addChild(AssetProvider.makeNode(for: .coin, radius: 10, fillColor: .systemYellow))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func markCollected() {
        isCollected = true
    }
}
