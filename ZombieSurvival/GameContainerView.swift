import SwiftUI
import SpriteKit
import UIKit

/// Hosts the SpriteKit scene. Built once via @State so device rotation or
/// SwiftUI re-renders never recreate (and reset) the running game.
struct GameContainerView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 60,
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
