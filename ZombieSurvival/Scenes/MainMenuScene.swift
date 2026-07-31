import SpriteKit
import UIKit

/// App entry point (replaces the Phase 1/2 stub). Play starts a new run via
/// MapSelectScene; Load Game and Settings are their own scenes.
final class MainMenuScene: SKScene {
    private let contentLayer = SKNode()

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
        addChild(contentLayer)
        rebuild()
    }

    private func rebuild() {
        contentLayer.removeAllChildren()

        let title = makeLabel("ZOMBIE SURVIVAL", fontSize: 34)
        title.position = CGPoint(x: 0, y: size.height / 2 - 90)
        contentLayer.addChild(title)

        let subtitle = makeLabel("2D Top-Down Shooter", fontSize: 16, color: .lightGray)
        subtitle.position = CGPoint(x: 0, y: size.height / 2 - 130)
        contentLayer.addChild(subtitle)

        let buttonSize = CGSize(width: 240, height: 56)
        let spacing: CGFloat = 68
        let startY: CGFloat = 40

        let play = makeButton(text: "PLAY", name: "play", size: buttonSize)
        play.position = CGPoint(x: 0, y: startY)
        contentLayer.addChild(play)

        let load = makeButton(text: "LOAD GAME", name: "loadGame", size: buttonSize)
        load.position = CGPoint(x: 0, y: startY - spacing)
        contentLayer.addChild(load)

        let settings = makeButton(text: "SETTINGS", name: "settings", size: buttonSize)
        settings.position = CGPoint(x: 0, y: startY - spacing * 2)
        contentLayer.addChild(settings)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name, let view = view else { return }

        switch name {
        case "play":
            let mapSelect = MapSelectScene(size: size)
            mapSelect.scaleMode = scaleMode
            view.presentScene(mapSelect, transition: .crossFade(withDuration: 0.3))
        case "loadGame":
            let loadGame = LoadGameScene(size: size)
            loadGame.scaleMode = scaleMode
            view.presentScene(loadGame, transition: .crossFade(withDuration: 0.3))
        case "settings":
            let settings = SettingsScene(size: size, context: .mainMenu)
            settings.scaleMode = scaleMode
            view.presentScene(settings, transition: .crossFade(withDuration: 0.3))
        default:
            break
        }
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

        let label = makeLabel(text, fontSize: 20)
        label.name = name
        button.addChild(label)
        return button
    }
}
