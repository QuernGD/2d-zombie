import SwiftUI

@main
struct ZombieSurvivalApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
