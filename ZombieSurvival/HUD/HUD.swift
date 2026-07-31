import SpriteKit

/// All HUD overlay elements: health bar, round counter, ammo counter,
/// "Next Round" button, and the game-over overlay. Positioned relative to
/// a centered-origin scene (anchorPoint 0.5, 0.5).
final class HUD: SKNode {
    private let sceneSize: CGSize

    private let healthBarBackground: SKShapeNode
    private let healthBarFill: SKShapeNode
    private let healthBarFillWidth: CGFloat
    private let roundLabel: SKLabelNode
    private let ammoLabel: SKLabelNode
    private let reloadLabel: SKLabelNode

    private var nextRoundButton: SKShapeNode?
    private var gameOverOverlay: SKNode?

    private static let healthBarWidth: CGFloat = 200
    private static let healthBarHeight: CGFloat = 22
    static let nextRoundButtonName = "nextRoundButton"
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

        roundLabel.position = CGPoint(x: 0, y: sceneSize.height / 2 - topInset)
        addChild(roundLabel)

        ammoLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: sceneSize.height / 2 - topInset)
        addChild(ammoLabel)

        reloadLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: sceneSize.height / 2 - topInset - 26)
        addChild(reloadLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(health: CGFloat, maxHealth: CGFloat, round: Int, ammo: Int, magazineSize: Int, isReloading: Bool) {
        let pct = max(0, min(1, maxHealth > 0 ? health / maxHealth : 0))
        healthBarFill.xScale = pct
        // Re-anchor the fill so it shrinks from the right, keeping the left edge fixed.
        healthBarFill.position.x = -(healthBarFillWidth / 2) * (1 - pct)
        healthBarFill.fillColor = pct > 0.5 ? .systemGreen : (pct > 0.2 ? .systemYellow : .systemRed)

        roundLabel.text = round > 0 ? "ROUND \(round)" : "GET READY"
        ammoLabel.text = "\(ammo) / \(magazineSize)"
        reloadLabel.text = isReloading ? "RELOADING…" : ""
    }

    func showNextRoundButton() {
        guard nextRoundButton == nil else { return }
        let button = makeButton(text: "NEXT ROUND", name: Self.nextRoundButtonName, size: CGSize(width: 220, height: 60))
        button.position = CGPoint(x: 0, y: -sceneSize.height / 2 + 110)
        addChild(button)
        nextRoundButton = button
    }

    func hideNextRoundButton() {
        nextRoundButton?.removeFromParent()
        nextRoundButton = nil
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

    private func makeButton(text: String, name: String, size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 10)
        button.fillColor = SKColor.darkGray.withAlphaComponent(0.9)
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = name

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }
}
