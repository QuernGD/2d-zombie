import SpriteKit
import UIKit

/// In-run pause menu: Resume, Settings, Save Game, Quit to Menu. Uses the
/// exact same mechanism as ShopScene — its own SKScene, GameScene fully
/// paused (isPaused + frozen gameClock) but never unloaded or recreated —
/// so Resume returns to gameplay exactly as it was.
final class PauseMenuScene: SKScene {
    private let gameScene: GameScene
    private let contentLayer = SKNode()
    private var showingSaveSlotPicker = false

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
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        addChild(contentLayer)
        rebuild()
    }

    private func rebuild() {
        contentLayer.removeAllChildren()
        if showingSaveSlotPicker {
            drawSaveSlotPicker()
        } else {
            drawMainMenu()
        }
    }

    private func drawMainMenu() {
        let title = makeLabel("PAUSED", fontSize: 30)
        title.position = CGPoint(x: 0, y: 110)
        contentLayer.addChild(title)

        let buttonSize = CGSize(width: 240, height: 52)
        let spacing: CGFloat = 64
        var y: CGFloat = 20

        let resume = makeButton(text: "RESUME", name: "resume", size: buttonSize)
        resume.position = CGPoint(x: 0, y: y)
        contentLayer.addChild(resume)
        y -= spacing

        let settings = makeButton(text: "SETTINGS", name: "settings", size: buttonSize)
        settings.position = CGPoint(x: 0, y: y)
        contentLayer.addChild(settings)
        y -= spacing

        let save = makeButton(text: "SAVE GAME", name: "saveGame", size: buttonSize)
        save.position = CGPoint(x: 0, y: y)
        contentLayer.addChild(save)
        y -= spacing

        let quit = makeButton(text: "QUIT TO MENU", name: "quitToMenu", size: buttonSize)
        quit.position = CGPoint(x: 0, y: y)
        contentLayer.addChild(quit)
    }

    private func drawSaveSlotPicker() {
        let title = makeLabel("SAVE TO WHICH SLOT?", fontSize: 22)
        title.position = CGPoint(x: 0, y: 130)
        contentLayer.addChild(title)

        for slot in 0..<SaveManager.slotCount {
            let summary = SaveManager.summary(forSlot: slot)
            let text: String
            if let summary {
                text = "Slot \(slot + 1): Round \(summary.round), \(summary.coins) coins"
            } else {
                text = "Slot \(slot + 1): Empty"
            }
            let button = makeButton(text: text, name: "saveSlot|\(slot)", size: CGSize(width: 320, height: 48))
            button.position = CGPoint(x: 0, y: 50 - CGFloat(slot) * 60)
            contentLayer.addChild(button)
        }

        let cancel = makeButton(text: "CANCEL", name: "cancelSave", size: CGSize(width: 160, height: 40))
        cancel.position = CGPoint(x: 0, y: 50 - CGFloat(SaveManager.slotCount) * 60 - 20)
        contentLayer.addChild(cancel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name else { return }
        let parts = name.split(separator: "|").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "resume":
            resume()
        case "settings":
            openSettings()
        case "saveGame":
            showingSaveSlotPicker = true
            rebuild()
        case "quitToMenu":
            quitToMenu()
        case "saveSlot":
            guard parts.count > 1, let slot = Int(parts[1]) else { return }
            saveToSlot(slot)
        case "cancelSave":
            showingSaveSlotPicker = false
            rebuild()
        default:
            break
        }
    }

    private func resume() {
        gameScene.isPaused = false
        gameScene.refreshControlSchemeIfNeeded()
        view?.presentScene(gameScene, transition: .crossFade(withDuration: 0.3))
    }

    private func openSettings() {
        guard let view = view else { return }
        let settings = SettingsScene(size: size, context: .midRunFromPause(gameScene))
        settings.scaleMode = scaleMode
        view.presentScene(settings, transition: .crossFade(withDuration: 0.3))
    }

    private func saveToSlot(_ slot: Int) {
        SaveManager.save(gameScene.gameState, toSlot: slot)
        showingSaveSlotPicker = false
        rebuild()
        showToast("Saved to Slot \(slot + 1)")
    }

    private func quitToMenu() {
        guard let view = view else { return }
        let menu = MainMenuScene(size: size)
        menu.scaleMode = scaleMode
        view.presentScene(menu, transition: .fade(withDuration: 0.4))
    }

    private func showToast(_ text: String) {
        let label = makeLabel(text, fontSize: 16, color: .systemGreen)
        label.position = CGPoint(x: 0, y: -size.height / 2 + 60)
        label.alpha = 0
        contentLayer.addChild(label)
        label.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 1.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, fontSize: CGFloat, color: SKColor = .white) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(text: String, name: String, size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 10)
        button.fillColor = SKColor.systemBlue.withAlphaComponent(0.85)
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = name

        let label = makeLabel(text, fontSize: 17)
        label.name = name
        button.addChild(label)
        return button
    }
}
