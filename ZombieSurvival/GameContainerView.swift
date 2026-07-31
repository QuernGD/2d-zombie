import SwiftUI
import SpriteKit
import UIKit

/// Hosts the SpriteKit scene. Built once via @State so device rotation or
/// SwiftUI re-renders never recreate (and reset) the running game. Boots
/// into MainMenuScene; every subsequent scene change happens via
/// view.presentScene(_:), the same mechanism used throughout (GameScene <->
/// ShopScene/PauseMenuScene/SettingsScene, menu <-> menu, etc.) — this
/// @State value only ever matters for the very first presentation.
struct GameContainerView: View {
    @State private var scene: SKScene = {
        let scene = MainMenuScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        // Reads the frame cap preference once, at first render. SwiftUI has
        // no path back from a SpriteKit scene's Settings changes to this
        // view (SettingsStore isn't an @Observable/@Published bridge), so a
        // frame cap change here takes effect on next launch, not live —
        // a known limitation, not a silent no-op.
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: SettingsStore.shared.frameCap.rawValue,
            options: [.ignoresSiblingOrder],
            debugOptions: debugOptions
        )
        .ignoresSafeArea()
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        return [.showsFPS, .showsNodeCount]
        #else
        return []
        #endif
    }
}
