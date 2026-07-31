import SpriteKit

final class Player: SKNode {
    let maxHealth: CGFloat
    let moveSpeed: CGFloat
    private(set) var health: CGFloat
    private(set) var facingAngle: CGFloat = 0
    let pistol: Pistol

    private let visualNode: SKNode
    private let facingIndicator: SKShapeNode

    var isAlive: Bool { health > 0 }

    init(maxHealth: CGFloat = Balance.playerMaxHealth, moveSpeed: CGFloat = Balance.playerMoveSpeed) {
        self.maxHealth = maxHealth
        self.health = maxHealth
        self.moveSpeed = moveSpeed
        self.pistol = Pistol()

        visualNode = AssetProvider.makeNode(for: .player, radius: Balance.playerRadius, fillColor: .systemGreen)

        facingIndicator = SKShapeNode(rectOf: CGSize(width: 6, height: Balance.playerRadius))
        facingIndicator.fillColor = .white
        facingIndicator.strokeColor = .clear
        facingIndicator.position = CGPoint(x: 0, y: Balance.playerRadius * 0.6)

        super.init()
        name = "player"
        zPosition = 100
        addChild(visualNode)
        addChild(facingIndicator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func takeDamage(_ amount: CGFloat) {
        health = max(0, health - amount)
    }

    func move(by vector: CGVector, deltaTime: TimeInterval, bounds: CGRect) {
        guard !vector.isZero else { return }
        let dx = vector.dx * moveSpeed * CGFloat(deltaTime)
        let dy = vector.dy * moveSpeed * CGFloat(deltaTime)
        var newPosition = CGPoint(x: position.x + dx, y: position.y + dy)
        newPosition.x = min(max(newPosition.x, bounds.minX + Balance.playerRadius), bounds.maxX - Balance.playerRadius)
        newPosition.y = min(max(newPosition.y, bounds.minY + Balance.playerRadius), bounds.maxY - Balance.playerRadius)
        position = newPosition
    }

    func setFacing(angle: CGFloat) {
        facingAngle = angle
        zRotation = angle - .pi / 2
    }
}
