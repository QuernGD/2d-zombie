import SpriteKit

/// The gun pinned to the bottom of the screen.
///
/// ⚠️ **Known art mismatch.** The pack's weapon sheets (Pistol_Shoot,
/// Rifle_Shoot, …) are small top-down/side-on pickup sprites, not
/// first-person hand-and-gun viewmodels. Pinned to the bottom of the screen
/// they read as a floating side-view gun, not something the player is
/// holding. This is wired up anyway so firing has visual feedback and the
/// plumbing is ready, but it needs purpose-drawn FPS viewmodel art to look
/// right. See the README.
final class WeaponViewModel {
    private let sprite = SKSpriteNode()
    private var framesByWeapon: [WeaponType: [SKTexture]] = [:]
    private var currentWeapon: WeaponType?
    private var sceneSize: CGSize = .zero
    private var restingPosition: CGPoint = .zero
    private var bobPhase: CGFloat = 0

    func install(in parent: SKNode, sceneSize: CGSize) {
        self.sceneSize = sceneSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition = 500
        let height = sceneSize.height * RaycasterConfig.viewmodelHeightFraction
        sprite.size = CGSize(width: height, height: height)
        restingPosition = CGPoint(x: sceneSize.width * 0.18, y: -sceneSize.height / 2)
        sprite.position = restingPosition
        if sprite.parent == nil { parent.addChild(sprite) }
    }

    /// Swaps in the idle (first) frame of the given weapon's shoot sheet.
    func setWeapon(_ weaponType: WeaponType?) {
        guard let weaponType else {
            sprite.isHidden = true
            currentWeapon = nil
            return
        }
        guard weaponType != currentWeapon else { return }
        currentWeapon = weaponType
        sprite.removeAllActions()

        guard let frames = frames(for: weaponType), let first = frames.first else {
            sprite.isHidden = true
            return
        }
        sprite.isHidden = false
        sprite.texture = first
    }

    /// Plays the weapon's shoot animation once. Firing faster than the
    /// animation simply restarts it, which reads better than queueing.
    func playFireAnimation(for weaponType: WeaponType) {
        setWeapon(weaponType)
        guard let frames = frames(for: weaponType), frames.count > 1 else { return }
        sprite.removeAction(forKey: "fire")
        sprite.run(
            .sequence([
                .animate(with: frames, timePerFrame: Balance.weaponShootFrameTime, resize: false, restore: true),
                .run { [weak self] in self?.sprite.texture = frames.first }
            ]),
            withKey: "fire"
        )
    }

    /// Subtle walk bob so the viewmodel isn't rigidly static. Driven off
    /// the scene's own clock, so it freezes with everything else on pause.
    func update(deltaTime: TimeInterval, movementMagnitude: CGFloat) {
        bobPhase += CGFloat(deltaTime) * RaycasterConfig.viewmodelBobFrequency * movementMagnitude
        let offset = sin(bobPhase) * RaycasterConfig.viewmodelBobAmplitude * movementMagnitude
        sprite.position = CGPoint(x: restingPosition.x, y: restingPosition.y + offset)
    }

    private func frames(for weaponType: WeaponType) -> [SKTexture]? {
        if let cached = framesByWeapon[weaponType] { return cached }
        guard let loaded = AssetProvider.loadSpriteSheetTextures(weaponType.shootSheet), !loaded.isEmpty else { return nil }
        framesByWeapon[weaponType] = loaded
        return loaded
    }
}
