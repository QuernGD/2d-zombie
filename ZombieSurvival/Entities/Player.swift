import SpriteKit

final class Player: SKNode {
    let baseMaxHealth: CGFloat
    let baseMoveSpeed: CGFloat
    private(set) var health: CGFloat
    private(set) var facingAngle: CGFloat = 0
    let inventory: WeaponInventory
    private(set) var perks: Set<Perk> = []

    private let visualNode: SKNode
    private let facingIndicator: SKShapeNode

    var isAlive: Bool { health > 0 }
    var activeWeapon: Weapon? { inventory.activeWeapon }

    /// Base value doubled by the Vitality perk.
    var maxHealth: CGFloat {
        baseMaxHealth * (perks.contains(.vitality) ? Balance.vitalityMaxHealthMultiplier : 1)
    }

    /// Base value boosted by the Sprinter perk.
    var moveSpeed: CGFloat {
        baseMoveSpeed * (perks.contains(.sprinter) ? Balance.sprinterMoveSpeedMultiplier : 1)
    }

    init(maxHealth: CGFloat = Balance.playerMaxHealth, moveSpeed: CGFloat = Balance.playerMoveSpeed) {
        self.baseMaxHealth = maxHealth
        self.health = maxHealth
        self.baseMoveSpeed = moveSpeed
        self.inventory = WeaponInventory()

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

    /// One-time purchase effect. Vitality tops up current health by the
    /// exact amount max health just increased, so buying it never makes an
    /// already-hurt player's health bar look worse.
    func applyPerk(_ perk: Perk) {
        guard !perks.contains(perk) else { return }
        let previousMaxHealth = maxHealth
        perks.insert(perk)
        if perk == .vitality {
            health += (maxHealth - previousMaxHealth)
        }
        inventory.refreshModifiers(perks: perks)
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
