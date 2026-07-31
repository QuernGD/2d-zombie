import SpriteKit
import UIKit

/// Lists all 3 save slots (round/coins/timestamp, or "Empty") using
/// SaveManager's lightweight summaries — never deserializes a full
/// GameState just to render this list. Tapping a non-empty slot loads it
/// into a fresh GameScene.
final class LoadGameScene: SKScene {
    private let contentLayer = SKNode()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
        addChild(contentLayer)
        rebuild()
    }

    private func rebuild() {
        contentLayer.removeAllChildren()

        let title = makeLabel("LOAD GAME", fontSize: 26)
        title.position = CGPoint(x: 0, y: size.height / 2 - 50)
        contentLayer.addChild(title)

        let rowHeight: CGFloat = 100
        let startY = size.height / 2 - 130

        for slot in 0..<SaveManager.slotCount {
            drawSlotRow(slot: slot, y: startY - CGFloat(slot) * rowHeight)
        }

        let back = makeButton(text: "BACK", name: "back", size: CGSize(width: 140, height: 44))
        back.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        contentLayer.addChild(back)
    }

    private func drawSlotRow(slot: Int, y: CGFloat) {
        let summary = SaveManager.summary(forSlot: slot)

        let card = SKShapeNode(rectOf: CGSize(width: 460, height: 76), cornerRadius: 10)
        card.fillColor = summary != nil ? SKColor.systemBlue.withAlphaComponent(0.25) : SKColor.darkGray.withAlphaComponent(0.35)
        card.strokeColor = .white
        card.lineWidth = 1.5
        card.position = CGPoint(x: 0, y: y)
        card.name = summary != nil ? "slot|\(slot)" : nil
        contentLayer.addChild(card)

        let title = makeLabel("SLOT \(slot + 1)", fontSize: 15, color: .lightGray)
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -210, y: 16)
        title.name = card.name
        card.addChild(title)

        let detail: String
        if let summary {
            let timestamp = Self.dateFormatter.string(from: summary.savedAt)
            detail = "Round \(summary.round) — \(summary.coins) coins — \(timestamp)"
        } else {
            detail = "Empty"
        }
        let detailLabel = makeLabel(detail, fontSize: 16, color: summary != nil ? .white : .gray)
        detailLabel.horizontalAlignmentMode = .left
        detailLabel.position = CGPoint(x: -210, y: -14)
        detailLabel.name = card.name
        card.addChild(detailLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name else { return }
        let parts = name.split(separator: "|").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "back":
            guard let view = view else { return }
            let menu = MainMenuScene(size: size)
            menu.scaleMode = scaleMode
            view.presentScene(menu, transition: .crossFade(withDuration: 0.3))
        case "slot":
            guard parts.count > 1, let slot = Int(parts[1]) else { return }
            loadSlot(slot)
        default:
            break
        }
    }

    private func loadSlot(_ slot: Int) {
        guard let state = SaveManager.loadState(fromSlot: slot), let view = view else { return }
        let scene = GameScene(size: size)
        scene.configureRestoring(state)
        scene.scaleMode = scaleMode
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
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
        button.fillColor = SKColor.darkGray.withAlphaComponent(0.9)
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = name

        let label = makeLabel(text, fontSize: 18)
        label.name = name
        button.addChild(label)
        return button
    }
}
