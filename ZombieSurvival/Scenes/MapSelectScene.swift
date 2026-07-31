import SpriteKit
import UIKit

/// Both maps are unlocked, no cost or restriction. They currently share
/// identical arena geometry and spawn layout — the background tint below is
/// the only visual difference right now. Selectable and fully functional,
/// just not yet visually distinct; see the root README.
enum MapID: String, Codable, CaseIterable {
    case original
    case ashyard

    var displayName: String {
        switch self {
        case .original: return "The Yard"
        case .ashyard: return "Ashyard"
        }
    }

    var backgroundColor: SKColor {
        switch self {
        case .original: return SKColor(red: 0.08, green: 0.10, blue: 0.08, alpha: 1.0)
        case .ashyard: return SKColor(red: 0.14, green: 0.09, blue: 0.08, alpha: 1.0)
        }
    }
}

/// Map + difficulty picker shown right before a new run starts. Difficulty
/// chosen here updates the same global SettingsStore preference shown in
/// SettingsScene — there's only one "current difficulty preference," just
/// two places to set it.
final class MapSelectScene: SKScene {
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

        let title = makeLabel("SELECT MAP", fontSize: 26)
        title.position = CGPoint(x: 0, y: size.height / 2 - 40)
        contentLayer.addChild(title)

        drawDifficultyRow()
        drawMapCards()
        drawBackButton()
    }

    private func drawDifficultyRow() {
        let label = makeLabel("DIFFICULTY", fontSize: 14, color: .lightGray)
        label.position = CGPoint(x: 0, y: size.height / 2 - 92)
        contentLayer.addChild(label)

        let current = SettingsStore.shared.difficulty
        let spacing: CGFloat = 140
        let startX = -spacing

        for (index, difficulty) in Difficulty.allCases.enumerated() {
            let button = makeButton(
                text: difficulty.displayName,
                name: "difficulty|\(difficulty.rawValue)",
                size: CGSize(width: 120, height: 40),
                highlighted: difficulty == current
            )
            button.position = CGPoint(x: startX + CGFloat(index) * spacing, y: size.height / 2 - 134)
            contentLayer.addChild(button)
        }
    }

    private func drawMapCards() {
        let spacing: CGFloat = 260
        let startX = -spacing / 2

        for (index, map) in MapID.allCases.enumerated() {
            let card = makeButton(text: map.displayName, name: "map|\(map.rawValue)", size: CGSize(width: 220, height: 140), fontSize: 18)
            card.position = CGPoint(x: startX + CGFloat(index) * spacing, y: 10)
            contentLayer.addChild(card)
        }

        let note = makeLabel("(currently identical layouts — background tint only)", fontSize: 12, color: .lightGray)
        note.position = CGPoint(x: 0, y: -90)
        contentLayer.addChild(note)
    }

    private func drawBackButton() {
        let button = makeButton(text: "BACK", name: "back", size: CGSize(width: 140, height: 44))
        button.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        contentLayer.addChild(button)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name else { return }
        let parts = name.split(separator: "|").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "back":
            goBack()
        case "difficulty":
            guard parts.count > 1, let difficulty = Difficulty(rawValue: parts[1]) else { return }
            SettingsStore.shared.difficulty = difficulty
            rebuild()
        case "map":
            guard parts.count > 1, let map = MapID(rawValue: parts[1]) else { return }
            startRun(mapID: map)
        default:
            break
        }
    }

    private func goBack() {
        guard let view = view else { return }
        let menu = MainMenuScene(size: size)
        menu.scaleMode = scaleMode
        view.presentScene(menu, transition: .crossFade(withDuration: 0.3))
    }

    private func startRun(mapID: MapID) {
        guard let view = view else { return }
        let scene = GameScene(size: size)
        scene.configureNewRun(mapID: mapID, difficulty: SettingsStore.shared.difficulty)
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

    private func makeButton(text: String, name: String, size: CGSize, fontSize: CGFloat = 15, highlighted: Bool = false) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 8)
        button.fillColor = highlighted ? SKColor.systemBlue.withAlphaComponent(0.9) : SKColor.darkGray.withAlphaComponent(0.7)
        button.strokeColor = .white
        button.lineWidth = highlighted ? 2.5 : 1.5
        button.name = name

        let label = makeLabel(text, fontSize: fontSize)
        label.name = name
        button.addChild(label)
        return button
    }
}
