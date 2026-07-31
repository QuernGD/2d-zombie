import SpriteKit
import UIKit

/// Round-end shop overlay. Presented as its own SKScene so GameScene can be
/// fully paused (not ticking, not unloaded, not recreated) while it's up;
/// closing re-presents that exact same GameScene instance, so position,
/// health, ammo, weapons, and perks all come back untouched.
///
/// Layout is a fixed, non-scrolling grid — fine on iPad landscape, tight on
/// smaller iPhones. A production pass would want a scrollable list; out of
/// scope here.
final class ShopScene: SKScene {
    private let gameScene: GameScene
    private let contentLayer = SKNode()
    private var pendingSlotChoice: (type: WeaponType, cost: Int)?

    private var player: Player { gameScene.player }
    private var economy: EconomyManager { gameScene.economyManager }

    init(size: CGSize, gameScene: GameScene) {
        self.gameScene = gameScene
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1.0)
        addChild(contentLayer)
        rebuild()
    }

    // MARK: - Layout

    private func rebuild() {
        contentLayer.removeAllChildren()
        pendingSlotChoice = nil
        drawHeader()
        drawActiveWeaponPanel()
        drawWeaponList()
        drawServicesColumn()
        drawPerksColumn()
        drawCloseButton()
    }

    private func drawHeader() {
        let title = makeLabel("SHOP", fontSize: 26)
        title.position = CGPoint(x: 0, y: size.height / 2 - 34)
        contentLayer.addChild(title)

        let coins = makeLabel("COINS: \(economy.coins)", fontSize: 18, color: .systemYellow)
        coins.position = CGPoint(x: size.width / 2 - 110, y: size.height / 2 - 34)
        contentLayer.addChild(coins)
    }

    private func drawActiveWeaponPanel() {
        let y = size.height / 2 - 74
        guard let weapon = player.activeWeapon else { return }

        let label = makeLabel("EQUIPPED: \(weapon.name) (Tier \(weapon.overclockTier))", fontSize: 15, alignment: .left)
        label.position = CGPoint(x: -size.width / 2 + 24, y: y)
        contentLayer.addChild(label)

        if player.inventory.slots[1 - player.inventory.activeIndex] != nil {
            let swap = makeButton(text: "SWAP ACTIVE", name: "swapActive", size: CGSize(width: 130, height: 30), fontSize: 12)
            swap.position = CGPoint(x: 0, y: y)
            contentLayer.addChild(swap)
        }

        let (label2, cost, maxed): (String, Int, Bool) = {
            switch weapon.overclockTier {
            case 0: return ("OVERCLOCK T1", Balance.overclockTier1Cost, false)
            case 1: return ("OVERCLOCK T2", Balance.overclockTier2Cost, false)
            default: return ("OVERCLOCKED — MAX", 0, true)
            }
        }()
        let overclock = makeButton(
            text: maxed ? label2 : "\(label2) - $\(cost)",
            name: "overclock",
            size: CGSize(width: 200, height: 30),
            fontSize: 12,
            enabled: !maxed && economy.canAfford(cost)
        )
        overclock.position = CGPoint(x: size.width / 2 - 130, y: y)
        contentLayer.addChild(overclock)
    }

    private func drawWeaponList() {
        let startY = size.height / 2 - 118
        let rowHeight: CGFloat = 32
        let x = -size.width / 2 + 180

        for (index, type) in WeaponType.allCases.enumerated() {
            drawWeaponRow(type: type, position: CGPoint(x: x, y: startY - CGFloat(index) * rowHeight))
        }
    }

    private func drawWeaponRow(type: WeaponType, position: CGPoint) {
        let owned = player.inventory.ownedTypes.contains(type)

        let nameLabel = makeLabel(type.displayName, fontSize: 14, alignment: .left)
        nameLabel.position = CGPoint(x: position.x - 160, y: position.y)
        contentLayer.addChild(nameLabel)

        if owned {
            let ownedLabel = makeLabel("OWNED", fontSize: 12, color: .systemGreen)
            ownedLabel.position = CGPoint(x: position.x + 70, y: position.y)
            contentLayer.addChild(ownedLabel)
        } else {
            let button = makeButton(
                text: "$\(type.cost)",
                name: "buyWeapon|\(type.rawValue)",
                size: CGSize(width: 90, height: 26),
                fontSize: 12,
                enabled: economy.canAfford(type.cost)
            )
            button.position = CGPoint(x: position.x + 70, y: position.y)
            contentLayer.addChild(button)
        }
    }

    private func drawServicesColumn() {
        let x = size.width / 2 - 180
        var y = size.height / 2 - 118

        drawServiceRow(title: "MYSTERY CRATE", cost: Balance.mysteryCrateCost, name: "crate", at: CGPoint(x: x, y: y))
        y -= 36
        drawServiceRow(title: "AMMO REFILL", cost: Balance.ammoRefillCost, name: "ammoRefill", at: CGPoint(x: x, y: y))
    }

    private func drawServiceRow(title: String, cost: Int, name: String, at position: CGPoint) {
        let label = makeLabel(title, fontSize: 13, alignment: .left)
        label.position = CGPoint(x: position.x - 160, y: position.y)
        contentLayer.addChild(label)

        let button = makeButton(text: "$\(cost)", name: name, size: CGSize(width: 90, height: 26), fontSize: 12, enabled: economy.canAfford(cost))
        button.position = CGPoint(x: position.x + 70, y: position.y)
        contentLayer.addChild(button)
    }

    private func drawPerksColumn() {
        let x = size.width / 2 - 180
        var y = size.height / 2 - 118 - 36 - 36 - 24

        let header = makeLabel("PERKS", fontSize: 14, alignment: .left)
        header.position = CGPoint(x: x - 160, y: y)
        contentLayer.addChild(header)
        y -= 28

        for perk in Perk.allCases {
            let owned = player.perks.contains(perk)
            let label = makeLabel("\(perk.displayName) — \(perk.summary)", fontSize: 11, alignment: .left)
            label.position = CGPoint(x: x - 160, y: y)
            contentLayer.addChild(label)

            if owned {
                let ownedLabel = makeLabel("OWNED", fontSize: 11, color: .systemGreen)
                ownedLabel.position = CGPoint(x: x + 80, y: y)
                contentLayer.addChild(ownedLabel)
            } else {
                let button = makeButton(
                    text: "$\(perk.cost)",
                    name: "perk|\(perk.rawValue)",
                    size: CGSize(width: 70, height: 24),
                    fontSize: 11,
                    enabled: economy.canAfford(perk.cost)
                )
                button.position = CGPoint(x: x + 80, y: y)
                contentLayer.addChild(button)
            }
            y -= 26
        }
    }

    private func drawCloseButton() {
        let button = makeButton(text: "CLOSE", name: "close", size: CGSize(width: 160, height: 44), fontSize: 16)
        button.position = CGPoint(x: 0, y: -size.height / 2 + 34)
        contentLayer.addChild(button)
    }

    private func showSlotChoicePrompt(type: WeaponType, cost: Int) {
        pendingSlotChoice = (type, cost)
        contentLayer.removeAllChildren()

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = SKColor.black.withAlphaComponent(0.85)
        dim.strokeColor = .clear
        contentLayer.addChild(dim)

        let question = makeLabel("Replace which weapon with \(type.displayName)?", fontSize: 17)
        question.position = CGPoint(x: 0, y: 70)
        contentLayer.addChild(question)

        for (index, weapon) in player.inventory.slots.enumerated() {
            let button = makeButton(
                text: "Slot \(index + 1): \(weapon?.name ?? "Empty")",
                name: "slotChoice|\(index)",
                size: CGSize(width: 280, height: 44)
            )
            button.position = CGPoint(x: 0, y: 10 - CGFloat(index) * 56)
            contentLayer.addChild(button)
        }

        let cancel = makeButton(text: "CANCEL", name: "cancelSlot", size: CGSize(width: 160, height: 38))
        cancel.position = CGPoint(x: 0, y: -110)
        contentLayer.addChild(cancel)
    }

    // MARK: - Buttons

    private func makeLabel(_ text: String, fontSize: CGFloat, color: SKColor = .white, alignment: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(text: String, name: String, size: CGSize, fontSize: CGFloat = 14, enabled: Bool = true) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 6)
        button.fillColor = enabled ? SKColor.systemBlue.withAlphaComponent(0.85) : SKColor.darkGray.withAlphaComponent(0.5)
        button.strokeColor = .white
        button.lineWidth = 1.5
        button.name = enabled ? name : nil

        let label = makeLabel(text, fontSize: fontSize)
        label.name = button.name
        button.addChild(label)
        return button
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name else { return }
        handleAction(name)
    }

    private func handleAction(_ name: String) {
        let parts = name.split(separator: "|").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "close":
            closeShop()
        case "swapActive":
            player.inventory.swapActive()
            rebuild()
        case "overclock":
            buyOverclock()
        case "crate":
            buyMysteryCrate()
        case "ammoRefill":
            buyAmmoRefill()
        case "buyWeapon":
            guard parts.count > 1, let type = WeaponType(rawValue: parts[1]) else { return }
            beginWeaponPurchase(type: type, cost: type.cost)
        case "perk":
            guard parts.count > 1, let perk = Perk(rawValue: parts[1]) else { return }
            buyPerk(perk)
        case "slotChoice":
            guard parts.count > 1, let slot = Int(parts[1]) else { return }
            confirmSlotChoice(slot: slot)
        case "cancelSlot":
            rebuild()
        default:
            break
        }
    }

    // MARK: - Purchases

    private func beginWeaponPurchase(type: WeaponType, cost: Int) {
        guard economy.canAfford(cost) else { return }
        if let emptySlot = player.inventory.firstEmptySlot() {
            completeWeaponPurchase(type: type, cost: cost, slot: emptySlot)
        } else {
            showSlotChoicePrompt(type: type, cost: cost)
        }
    }

    private func confirmSlotChoice(slot: Int) {
        guard let pending = pendingSlotChoice else { return }
        completeWeaponPurchase(type: pending.type, cost: pending.cost, slot: slot)
    }

    private func completeWeaponPurchase(type: WeaponType, cost: Int, slot: Int) {
        guard economy.spend(cost) else { return }
        let weapon = type.makeWeapon()
        player.inventory.equip(weapon, inSlot: slot)
        player.inventory.refreshModifiers(perks: player.perks)
        rebuild()
    }

    private func buyMysteryCrate() {
        guard economy.spend(Balance.mysteryCrateCost) else { return }
        let type = economy.rollMysteryCrateWeapon(owned: player.inventory.ownedTypes)
        if let emptySlot = player.inventory.firstEmptySlot() {
            let weapon = type.makeWeapon()
            player.inventory.equip(weapon, inSlot: emptySlot)
            player.inventory.refreshModifiers(perks: player.perks)
            rebuild()
        } else {
            // Coins are already spent on the roll; the slot prompt here just
            // decides which weapon the prize replaces, at zero extra cost.
            showSlotChoicePrompt(type: type, cost: 0)
        }
    }

    private func buyAmmoRefill() {
        guard let weapon = player.activeWeapon, economy.spend(Balance.ammoRefillCost) else { return }
        weapon.refillMagazine()
        rebuild()
    }

    private func buyOverclock() {
        guard let weapon = player.activeWeapon else { return }
        let cost: Int
        switch weapon.overclockTier {
        case 0: cost = Balance.overclockTier1Cost
        case 1: cost = Balance.overclockTier2Cost
        default: return
        }
        guard economy.spend(cost) else { return }
        weapon.overclockTier += 1
        rebuild()
    }

    private func buyPerk(_ perk: Perk) {
        guard !player.perks.contains(perk), economy.spend(perk.cost) else { return }
        player.applyPerk(perk)
        rebuild()
    }

    private func closeShop() {
        gameScene.isPaused = false
        view?.presentScene(gameScene, transition: .crossFade(withDuration: 0.3))
    }
}
