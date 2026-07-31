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

/// Displays health as a stretched color-swatch sprite (health_bar_fillers.png,
/// Phase 4), falling back to a plain colored rect if that sheet fails to
/// load. Either way, the same xScale-based "shrink from the right, left edge
/// fixed" animation applies.
private final class HealthFillNode: SKNode {
    private let width: CGFloat
    private let sprite: SKSpriteNode?
    private let shape: SKShapeNode?
    private let healthyTexture: SKTexture?
    private let mediumTexture: SKTexture?
    private let criticalTexture: SKTexture?

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        let textures = AssetProvider.loadSpriteSheetTextures(SpriteSheetFrames(
            sheetName: "health_bar_fillers",
            frameSize: Balance.healthBarFillerSwatchSize,
            frameCount: Balance.healthBarFillerSwatchCount,
            subdirectory: "Assets/UI"
        ))
        if let textures, textures.count == Balance.healthBarFillerSwatchCount {
            // Swatch order (left to right): red/maroon, blue, orange/brown, green.
            criticalTexture = textures[0]
            mediumTexture = textures[2]
            healthyTexture = textures[3]
            sprite = SKSpriteNode(texture: healthyTexture, size: CGSize(width: width, height: height))
            shape = nil
        } else {
            healthyTexture = nil
            mediumTexture = nil
            criticalTexture = nil
            sprite = nil
            let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 3)
            node.strokeColor = .clear
            shape = node
        }
        super.init()
        if let sprite { addChild(sprite) }
        if let shape { addChild(shape) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(percent: CGFloat) {
        let clamped = max(0, min(1, percent))
        let offsetX = -(width / 2) * (1 - clamped)
        if let sprite {
            sprite.xScale = clamped
            sprite.position.x = offsetX
            sprite.texture = clamped > 0.5 ? healthyTexture : (clamped > 0.2 ? mediumTexture : criticalTexture)
        } else if let shape {
            shape.xScale = clamped
            shape.position.x = offsetX
            shape.fillColor = clamped > 0.5 ? .systemGreen : (clamped > 0.2 ? .systemYellow : .systemRed)
        }
    }
}

/// All HUD overlay elements: health bar, round counter, ammo counter, coin
/// counter, active weapon name, weapon-swap button, owned-perk icons,
/// "Next Round"/"Shop" buttons, and the game-over overlay. Positioned
/// relative to a centered-origin scene (anchorPoint 0.5, 0.5).
final class HUD: SKNode {
    private let sceneSize: CGSize

    private let healthBarBackground: SKNode
    private let healthBarFill: HealthFillNode
    private let healthBarFillWidth: CGFloat
    private let roundLabel: SKLabelNode
    private let coinsLabel: SKLabelNode
    private let weaponNameLabel: SKLabelNode
    private let ammoLabel: SKLabelNode
    private let reloadLabel: SKLabelNode
    private let perkIconsNode = SKNode()

    private var nextRoundButton: SKShapeNode?
    private var shopButton: SKShapeNode?
    private var pauseButton: SKShapeNode?
    private var swapWeaponButton: SKShapeNode?
    private var gameOverOverlay: SKNode?
    private var lastDisplayedPerks: Set<Perk> = []

    private static let healthBarWidth: CGFloat = 200
    private static let healthBarHeight: CGFloat = 22
    static let nextRoundButtonName = "nextRoundButton"
    static let shopButtonName = "shopButton"
    static let pauseButtonName = "pauseButton"
    static let swapWeaponButtonName = "swapWeaponButton"
    static let restartButtonName = "restartButton"
    static let restartFromSaveButtonName = "restartFromSaveButton"
    static let quitButtonName = "quitButton"

    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize

        let backgroundSize = CGSize(width: Self.healthBarWidth, height: Self.healthBarHeight)
        if let panel = AssetProvider.makeResizablePanel(sheetName: "panel1", subdirectory: "Assets/UI", size: backgroundSize) {
            healthBarBackground = panel
        } else {
            let shape = SKShapeNode(rectOf: backgroundSize, cornerRadius: 4)
            shape.fillColor = SKColor.black.withAlphaComponent(0.5)
            shape.strokeColor = .white
            shape.lineWidth = 1.5
            healthBarBackground = shape
        }

        healthBarFillWidth = Self.healthBarWidth - 4
        healthBarFill = HealthFillNode(width: healthBarFillWidth, height: Self.healthBarHeight - 4)

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
        healthBarFill.update(percent: pct)

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

    /// Always visible during a round (not just between rounds), unlike
    /// Next Round/Shop.
    func showPauseButton() {
        guard pauseButton == nil else { return }
        let button = makeButton(text: "PAUSE", name: Self.pauseButtonName, size: CGSize(width: 90, height: 40), fontSize: 14)
        button.position = CGPoint(x: 0, y: sceneSize.height / 2 - 100)
        addChild(button)
        pauseButton = button
    }

    func showGameOver(round: Int, hasAnySave: Bool) {
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
        title.position = CGPoint(x: 0, y: 100)
        overlay.addChild(title)

        let roundReached = SKLabelNode(fontNamed: "Menlo-Bold")
        roundReached.text = "Round Reached: \(round)"
        roundReached.fontSize = 22
        roundReached.fontColor = .white
        roundReached.position = CGPoint(x: 0, y: 50)
        overlay.addChild(roundReached)

        let restartButton = makeButton(text: "RESTART", name: Self.restartButtonName, size: CGSize(width: 220, height: 50))
        restartButton.position = CGPoint(x: 0, y: -20)
        overlay.addChild(restartButton)

        let restartFromSaveButton = makeButton(
            text: "RESTART FROM LAST SAVE",
            name: Self.restartFromSaveButtonName,
            size: CGSize(width: 220, height: 50),
            fontSize: 14,
            enabled: hasAnySave
        )
        restartFromSaveButton.position = CGPoint(x: 0, y: -80)
        overlay.addChild(restartFromSaveButton)

        let quitButton = makeButton(text: "QUIT", name: Self.quitButtonName, size: CGSize(width: 220, height: 50))
        quitButton.position = CGPoint(x: 0, y: -140)
        overlay.addChild(quitButton)

        addChild(overlay)
        gameOverOverlay = overlay
    }

    func hideGameOver() {
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil
    }

    private func makeButton(text: String, name: String, size: CGSize, fontSize: CGFloat = 18, enabled: Bool = true) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 10)
        button.fillColor = enabled ? SKColor.darkGray.withAlphaComponent(0.9) : SKColor.darkGray.withAlphaComponent(0.35)
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = enabled ? name : nil

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = enabled ? .white : .gray
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = button.name
        button.addChild(label)

        return button
    }
}
