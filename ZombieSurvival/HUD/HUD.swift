import SpriteKit

/// Everything HUD.update needs each frame, bundled so the method signature
/// doesn't keep growing a parameter at a time as features are added.
struct HUDDisplayState {
    let health: CGFloat
    let maxHealth: CGFloat
    let round: Int
    let ammo: Int
    let magazineSize: Int
    let isReloading: Bool
    let weaponName: String
    let coins: Int
    let perks: Set<Perk>
    let showSwapButton: Bool
}

/// All HUD overlay elements: health bar, round counter, ammo counter, coin
/// counter, active weapon name, weapon-swap button, owned-perk icons,
/// "Next Round"/"Shop" buttons, and the game-over overlay. Positioned
/// relative to a centered-origin scene (anchorPoint 0.5, 0.5).
final class HUD: SKNode {
    private let sceneSize: CGSize

    private let healthBarBackground: SKShapeNode
    private let healthBarFill: SKShapeNode
    private let healthBarFillWidth: CGFloat
    private let roundLabel: SKLabelNode
    private let coinsLabel: SKLabelNode
    private let weaponNameLabel: SKLabelNode
    private let ammoLabel: SKLabelNode
    private let reloadLabel: SKLabelNode
    private let perkIconsNode = SKNode()

    private var nextRoundButton: SKShapeNode?
    private var shopButton: SKShapeNode?
    private var swapWeaponButton: SKShapeNode?
    private var gameOverOverlay: SKNode?
    private var lastDisplayedPerks: Set<Perk> = []

    private static let healthBarWidth: CGFloat = 200
    private static let healthBarHeight: CGFloat = 22
    static let nextRoundButtonName = "nextRoundButton"
    static let shopButtonName = "shopButton"
    static let swapWeaponButtonName = "swapWeaponButton"
    static let restartButtonName = "restartButton"
    static let mainMenuButtonName = "mainMenuButton"

    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize

        healthBarBackground = SKShapeNode(rectOf: CGSize(width: Self.healthBarWidth, height: Self.healthBarHeight), cornerRadius: 4)
        healthBarBackground.fillColor = SKColor.black.withAlphaComponent(0.5)
        healthBarBackground.strokeColor = .white
        healthBarBackground.lineWidth = 1.5

        healthBarFillWidth = Self.healthBarWidth - 4
        healthBarFill = SKShapeNode(rectOf: CGSize(width: healthBarFillWidth, height: Self.healthBarHeight - 4), cornerRadius: 3)
        healthBarFill.fillColor = .systemGreen
        healthBarFill.strokeColor = .clear

        roundLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        roundLabel.fontSize = 20
        roundLabel.fontColor = .white
        roundLabel.horizontalAlignmentMode = .center
        roundLabel.verticalAlignmentMode = .center

        coinsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        coinsLabel.fontSize = 15
        coinsLabel.fontColor = .systemYellow
        coinsLabel.horizontalAlignmentMode = .center
        coinsLabel.verticalAlignmentMode = .center

        weaponNameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        weaponNameLabel.fontSize = 14
        weaponNameLabel.fontColor = .white
        weaponNameLabel.horizontalAlignmentMode = .right
        weaponNameLabel.verticalAlignmentMode = .center

        ammoLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        ammoLabel.fontSize = 18
        ammoLabel.fontColor = .white
        ammoLabel.horizontalAlignmentMode = .right
        ammoLabel.verticalAlignmentMode = .center

        reloadLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        reloadLabel.fontSize = 14
        reloadLabel.fontColor = .yellow
        reloadLabel.horizontalAlignmentMode = .right
        reloadLabel.verticalAlignmentMode = .center
        reloadLabel.text = ""

        super.init()
        zPosition = 2000

        let topInset: CGFloat = 40
        healthBarBackground.position = CGPoint(x: -sceneSize.width / 2 + Self.healthBarWidth / 2 + 24, y: sceneSize.height / 2 - topInset)
        // healthBarFill is left-anchored within the bar via a wrapper offset, achieved by scaling from the left edge.
        healthBarFill.position = .zero
        healthBarBackground.addChild(healthBarFill)
        addChild(healthBarBackground)

        perkIconsNode.position = CGPoint(x: -sceneSize.width / 2 + 24, y: sceneSize.height / 2 - topInset - 26)
        addChild(perkIconsNode)

        roundLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - topInset)
        addChild(roundLabel)

        coinsLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - topInset - 24)
        addChild(coinsLabel)

        weaponNameLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: sceneSize.height / 2 - topInset + 20)
        addChild(weaponNameLabel)

        ammoLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: sceneSize.height / 2 - topInset)
        addChild(ammoLabel)

        reloadLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: sceneSize.height / 2 - topInset - 26)
        addChild(reloadLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with state: HUDDisplayState) {
        let pct = max(0, min(1, state.maxHealth > 0 ? state.health / state.maxHealth : 0))
        healthBarFill.xScale = pct
        // Re-anchor the fill so it shrinks from the right, keeping the left edge fixed.
        healthBarFill.position.x = -(healthBarFillWidth / 2) * (1 - pct)
        healthBarFill.fillColor = pct > 0.5 ? .systemGreen : (pct > 0.2 ? .systemYellow : .systemRed)

        roundLabel.text = state.round > 0 ? "ROUND \(state.round)" : "GET READY"
        coinsLabel.text = "COINS: \(state.coins)"
        weaponNameLabel.text = state.weaponName
        ammoLabel.text = "\(state.ammo) / \(state.magazineSize)"
        reloadLabel.text = state.isReloading ? "RELOADING…" : ""

        if state.perks != lastDisplayedPerks {
            lastDisplayedPerks = state.perks
            rebuildPerkIcons(state.perks)
        }

        if state.showSwapButton {
            showSwapButton()
        } else {
            hideSwapButton()
        }
    }

    private func rebuildPerkIcons(_ perks: Set<Perk>) {
        perkIconsNode.removeAllChildren()
        let ordered = Perk.allCases.filter { perks.contains($0) }
        for (index, perk) in ordered.enumerated() {
            let icon = SKShapeNode(rectOf: CGSize(width: 22, height: 22), cornerRadius: 4)
            icon.fillColor = perk.iconColor
            icon.strokeColor = .white
            icon.lineWidth = 1
            icon.position = CGPoint(x: CGFloat(index) * 26 + 11, y: -11)

            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = perk.iconInitial
            label.fontSize = 12
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            icon.addChild(label)

            perkIconsNode.addChild(icon)
        }
    }

    private func showSwapButton() {
        guard swapWeaponButton == nil else { return }
        let button = makeButton(text: "SWAP", name: Self.swapWeaponButtonName, size: CGSize(width: 90, height: 26), fontSize: 13)
        button.position = CGPoint(x: sceneSize.width / 2 - 24 - 45, y: sceneSize.height / 2 - 40 - 56)
        addChild(button)
        swapWeaponButton = button
    }

    private func hideSwapButton() {
        swapWeaponButton?.removeFromParent()
        swapWeaponButton = nil
    }

    func showNextRoundButton() {
        guard nextRoundButton == nil else { return }
        let button = makeButton(text: "NEXT ROUND", name: Self.nextRoundButtonName, size: CGSize(width: 200, height: 60))
        button.position = CGPoint(x: 115, y: -sceneSize.height / 2 + 110)
        addChild(button)
        nextRoundButton = button
    }

    func hideNextRoundButton() {
        nextRoundButton?.removeFromParent()
        nextRoundButton = nil
    }

    func showShopButton() {
        guard shopButton == nil else { return }
        let button = makeButton(text: "SHOP", name: Self.shopButtonName, size: CGSize(width: 200, height: 60))
        button.position = CGPoint(x: -115, y: -sceneSize.height / 2 + 110)
        addChild(button)
        shopButton = button
    }

    func hideShopButton() {
        shopButton?.removeFromParent()
        shopButton = nil
    }

    func showGameOver(round: Int) {
        guard gameOverOverlay == nil else { return }
        let overlay = SKNode()
        overlay.zPosition = 3000

        let dim = SKShapeNode(rectOf: sceneSize)
        dim.fillColor = SKColor.black.withAlphaComponent(0.75)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "GAME OVER"
        title.fontSize = 40
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 70)
        overlay.addChild(title)

        let roundReached = SKLabelNode(fontNamed: "Menlo-Bold")
        roundReached.text = "Round Reached: \(round)"
        roundReached.fontSize = 22
        roundReached.fontColor = .white
        roundReached.position = CGPoint(x: 0, y: 20)
        overlay.addChild(roundReached)

        let restartButton = makeButton(text: "RESTART", name: Self.restartButtonName, size: CGSize(width: 200, height: 50))
        restartButton.position = CGPoint(x: 0, y: -50)
        overlay.addChild(restartButton)

        // Stubbed: no main menu exists yet in this phase.
        let menuButton = makeButton(text: "MAIN MENU", name: Self.mainMenuButtonName, size: CGSize(width: 200, height: 50))
        menuButton.position = CGPoint(x: 0, y: -120)
        overlay.addChild(menuButton)

        addChild(overlay)
        gameOverOverlay = overlay
    }

    func hideGameOver() {
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil
    }

    private func makeButton(text: String, name: String, size: CGSize, fontSize: CGFloat = 18) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 10)
        button.fillColor = SKColor.darkGray.withAlphaComponent(0.9)
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = name

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }
}
