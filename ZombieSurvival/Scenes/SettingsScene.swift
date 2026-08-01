import SpriteKit
import UIKit

/// Reachable from the main menu and mid-run (from the shop or the pause
/// menu). Persists everything to SettingsStore (UserDefaults) immediately
/// on change — there's no separate "Save" button here, unlike run saves.
///
/// Difficulty is the one control that isn't always editable: mid-run it
/// shows the *run's* locked difficulty (from GameScene.gameState) as
/// read-only text, since changing the global preference here must not
/// retroactively affect a run already in progress.
final class SettingsScene: SKScene {
    enum Context {
        case mainMenu
        case midRunFromShop(GameScene)
        case midRunFromPause(GameScene)
    }

    private let context: Context
    private let contentLayer = SKNode()
    private var store: SettingsStore { SettingsStore.shared }

    private var midRunGameScene: GameScene? {
        switch context {
        case .mainMenu: return nil
        case .midRunFromShop(let gameScene), .midRunFromPause(let gameScene): return gameScene
        }
    }

    init(size: CGSize, context: Context) {
        self.context = context
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
        addPanelBackground()
        addChild(contentLayer)
        rebuild()
    }

    /// A 9-sliced panel2 background inset from the scene edges (panel2's
    /// ornate orange-riveted border, distinguishing Settings from the
    /// plainer panel1 used by Shop/HUD). Skipped, leaving the flat
    /// backgroundColor, if panel2 fails to load.
    private func addPanelBackground() {
        guard let panel = AssetProvider.makeResizablePanel(
            sheetName: "panel2", subdirectory: "Assets/UI",
            size: CGSize(width: size.width - 32, height: size.height - 32)
        ) else { return }
        panel.zPosition = -1
        addChild(panel)
    }

    // MARK: - Layout

    private func rebuild() {
        contentLayer.removeAllChildren()

        let title = makeLabel("SETTINGS", fontSize: 26)
        title.position = CGPoint(x: 0, y: size.height / 2 - 34)
        contentLayer.addChild(title)

        let leftX = -size.width / 2 + 30
        let rightX = size.width / 2 - 260
        var leftY = size.height / 2 - 84
        var rightY = size.height / 2 - 84

        leftY = drawSectionHeader("AUDIO", x: leftX, y: leftY)
        leftY = drawSteppedControl(label: "Master Volume", valueName: "masterVolume", currentValue: store.masterVolume, x: leftX, y: leftY)
        leftY = drawSteppedControl(label: "SFX Volume", valueName: "sfxVolume", currentValue: store.sfxVolume, x: leftX, y: leftY)
        leftY = drawToggleRow(label: "Mute", isOn: store.isMuted, name: "toggleMute", x: leftX, y: leftY)
        leftY -= 12

        // First person has a single control scheme (move stick + drag to
        // look), so the old scheme picker is gone; what matters now is how
        // fast dragging turns you.
        leftY = drawSectionHeader("CONTROLS", x: leftX, y: leftY)
        leftY = drawSteppedControl(
            label: "Look Sensitivity",
            valueName: "lookSensitivity",
            currentValue: normalisedLookSensitivity,
            x: leftX, y: leftY
        )

        rightY = drawSectionHeader("GRAPHICS", x: rightX, y: rightY)
        // Raycaster column count — the main frame-time dial.
        rightY = drawOptionRow(
            options: RenderQuality.allCases,
            current: store.renderQuality,
            namePrefix: "renderQuality",
            rawValue: { $0.rawValue },
            display: { $0.displayName },
            x: rightX, y: rightY, buttonWidth: 65, label: "Resolution"
        )
        rightY = drawOptionRow(
            options: ParticleDensity.allCases,
            current: store.particleDensity,
            namePrefix: "particleDensity",
            rawValue: { $0.rawValue },
            display: { $0.displayName },
            x: rightX, y: rightY, buttonWidth: 65, label: "Particles"
        )
        rightY = drawToggleRow(label: "Blood Effects", isOn: store.bloodEffectsEnabled, name: "toggleBlood", x: rightX, y: rightY)
        rightY = drawToggleRow(label: "Screen Shake", isOn: store.screenShakeEnabled, name: "toggleScreenShake", x: rightX, y: rightY)
        rightY = drawToggleRow(label: "Damage Numbers", isOn: store.damageNumbersEnabled, name: "toggleDamageNumbers", x: rightX, y: rightY)
        rightY = drawOptionRow(
            options: FrameCap.allCases,
            current: store.frameCap,
            namePrefix: "frameCap",
            rawValue: { String($0.rawValue) },
            display: { $0.displayName },
            x: rightX, y: rightY, buttonWidth: 65, label: "Frame Cap"
        )
        rightY -= 12

        rightY = drawSectionHeader("DIFFICULTY", x: rightX, y: rightY)
        drawDifficultyRow(x: rightX, y: rightY)

        drawBackButton()
    }

    /// The stepped control draws 0...1, so map the sensitivity multiplier
    /// into that range for display.
    private var normalisedLookSensitivity: Float {
        let span = RaycasterConfig.maximumLookSensitivity - RaycasterConfig.minimumLookSensitivity
        guard span > 0 else { return 1 }
        return (store.lookSensitivity - RaycasterConfig.minimumLookSensitivity) / span
    }

    private func drawDifficultyRow(x: CGFloat, y: CGFloat) {
        if case .mainMenu = context {
            _ = drawOptionRow(
                options: Difficulty.allCases,
                current: store.difficulty,
                namePrefix: "difficulty",
                rawValue: { $0.rawValue },
                display: { $0.displayName },
                x: x, y: y, buttonWidth: 65
            )
        } else if let gameScene = midRunGameScene {
            let locked = makeLabel("\(gameScene.gameState.difficulty.displayName) — locked for this run", fontSize: 13, color: .lightGray, alignment: .left)
            locked.position = CGPoint(x: x, y: y)
            contentLayer.addChild(locked)
        }
    }

    private func drawBackButton() {
        let button = makeButton(text: "BACK", name: "back", size: CGSize(width: 140, height: 44))
        button.position = CGPoint(x: 0, y: -size.height / 2 + 34)
        contentLayer.addChild(button)
    }

    // MARK: - Row helpers (each returns the y for the next row)

    private func drawSectionHeader(_ text: String, x: CGFloat, y: CGFloat) -> CGFloat {
        let header = makeLabel(text, fontSize: 15, color: .systemYellow, alignment: .left)
        header.position = CGPoint(x: x, y: y)
        contentLayer.addChild(header)
        return y - 30
    }

    private func drawSteppedControl(label: String, valueName: String, currentValue: Float, x: CGFloat, y: CGFloat) -> CGFloat {
        let labelNode = makeLabel(label, fontSize: 13, alignment: .left)
        labelNode.position = CGPoint(x: x, y: y)
        contentLayer.addChild(labelNode)

        let steps = Balance.volumeSliderSteps
        let currentStep = Int((currentValue * Float(steps)).rounded())
        let squareSize: CGFloat = 20
        let spacing: CGFloat = 24
        let startX = x + 140

        for index in 0..<steps {
            let filled = index < currentStep
            let square = SKShapeNode(rectOf: CGSize(width: squareSize, height: squareSize), cornerRadius: 3)
            square.fillColor = filled ? SKColor.systemGreen.withAlphaComponent(0.85) : SKColor.darkGray.withAlphaComponent(0.5)
            square.strokeColor = .white
            square.lineWidth = 1
            square.position = CGPoint(x: startX + CGFloat(index) * spacing, y: y)
            square.name = "\(valueName)|\(index + 1)"
            contentLayer.addChild(square)
        }
        return y - 30
    }

    private func drawToggleRow(label: String, isOn: Bool, name: String, x: CGFloat, y: CGFloat) -> CGFloat {
        let labelNode = makeLabel(label, fontSize: 13, alignment: .left)
        labelNode.position = CGPoint(x: x, y: y)
        contentLayer.addChild(labelNode)

        let button = makeButton(text: isOn ? "ON" : "OFF", name: name, size: CGSize(width: 70, height: 26), fontSize: 12, highlighted: isOn)
        button.position = CGPoint(x: x + 175, y: y)
        contentLayer.addChild(button)
        return y - 30
    }

    private func drawOptionRow<T: Equatable>(
        options: [T],
        current: T,
        namePrefix: String,
        rawValue: (T) -> String,
        display: (T) -> String,
        x: CGFloat,
        y: CGFloat,
        buttonWidth: CGFloat,
        label: String? = nil
    ) -> CGFloat {
        var bx = x
        if let label {
            let labelNode = makeLabel(label, fontSize: 13, alignment: .left)
            labelNode.position = CGPoint(x: x, y: y)
            contentLayer.addChild(labelNode)
            bx = x + 100
        }

        for option in options {
            let button = makeButton(
                text: display(option),
                name: "\(namePrefix)|\(rawValue(option))",
                size: CGSize(width: buttonWidth, height: 26),
                fontSize: 11,
                highlighted: option == current
            )
            button.position = CGPoint(x: bx + buttonWidth / 2, y: y)
            contentLayer.addChild(button)
            bx += buttonWidth + 8
        }
        return y - 30
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = atPoint(touch.location(in: self)).name else { return }
        let parts = name.split(separator: "|").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "back":
            close()
        case "masterVolume":
            guard parts.count > 1, let level = Int(parts[1]) else { return }
            let value = Float(level) / Float(Balance.volumeSliderSteps)
            store.masterVolume = value
            AudioManagerProvider.shared.setMasterVolume(value)
            rebuild()
        case "sfxVolume":
            guard parts.count > 1, let level = Int(parts[1]) else { return }
            let value = Float(level) / Float(Balance.volumeSliderSteps)
            store.sfxVolume = value
            AudioManagerProvider.shared.setSFXVolume(value)
            rebuild()
        case "toggleMute":
            store.isMuted.toggle()
            AudioManagerProvider.shared.setMuted(store.isMuted)
            rebuild()
        case "toggleBlood":
            store.bloodEffectsEnabled.toggle()
            rebuild()
        case "toggleScreenShake":
            store.screenShakeEnabled.toggle()
            rebuild()
        case "toggleDamageNumbers":
            store.damageNumbersEnabled.toggle()
            rebuild()
        case "particleDensity":
            guard parts.count > 1, let density = ParticleDensity(rawValue: parts[1]) else { return }
            store.particleDensity = density
            rebuild()
        case "frameCap":
            guard parts.count > 1, let rawInt = Int(parts[1]), let cap = FrameCap(rawValue: rawInt) else { return }
            store.frameCap = cap
            rebuild()
        case "lookSensitivity":
            guard parts.count > 1, let level = Int(parts[1]) else { return }
            let fraction = Float(level) / Float(Balance.volumeSliderSteps)
            store.lookSensitivity = RaycasterConfig.minimumLookSensitivity
                + (RaycasterConfig.maximumLookSensitivity - RaycasterConfig.minimumLookSensitivity) * fraction
            midRunGameScene?.refreshControlSchemeIfNeeded()
            rebuild()
        case "renderQuality":
            guard parts.count > 1, let quality = RenderQuality(rawValue: parts[1]) else { return }
            store.renderQuality = quality
            midRunGameScene?.refreshControlSchemeIfNeeded()
            rebuild()
        case "difficulty":
            guard case .mainMenu = context, parts.count > 1, let difficulty = Difficulty(rawValue: parts[1]) else { return }
            store.difficulty = difficulty
            rebuild()
        default:
            break
        }
    }

    private func close() {
        guard let view = view else { return }
        switch context {
        case .mainMenu:
            let menu = MainMenuScene(size: size)
            menu.scaleMode = scaleMode
            view.presentScene(menu, transition: .crossFade(withDuration: 0.3))
        case .midRunFromShop(let gameScene):
            let shop = ShopScene(size: size, gameScene: gameScene)
            shop.scaleMode = scaleMode
            view.presentScene(shop, transition: .crossFade(withDuration: 0.3))
        case .midRunFromPause(let gameScene):
            let pause = PauseMenuScene(size: size, gameScene: gameScene)
            pause.scaleMode = scaleMode
            view.presentScene(pause, transition: .crossFade(withDuration: 0.3))
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, fontSize: CGFloat, color: SKColor = .white, alignment: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(text: String, name: String, size: CGSize, fontSize: CGFloat = 14, highlighted: Bool = false) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: 6)
        button.fillColor = highlighted ? SKColor.systemBlue.withAlphaComponent(0.9) : SKColor.darkGray.withAlphaComponent(0.6)
        button.strokeColor = .white
        button.lineWidth = highlighted ? 2 : 1.5
        button.name = name

        let label = makeLabel(text, fontSize: fontSize)
        label.name = name
        button.addChild(label)
        return button
    }
}
