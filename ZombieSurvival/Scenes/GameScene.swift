import SpriteKit
import UIKit

/// The first-person game scene.
///
/// Everything above gameplay carried over untouched — WaveManager,
/// EconomyManager, SaveManager, GameState, Balance, perks, the whole weapon
/// catalogue and every menu/shop scene. This class keeps exactly the public
/// surface those depend on (`player`, `economyManager`, `gameState`,
/// `configureNewRun`, `configureRestoring`, `refreshControlSchemeIfNeeded`)
/// so none of them needed editing; only what's *between* input and pixels
/// changed from top-down to raycast.
final class GameScene: SKScene {
    private(set) var player = Player()
    private(set) var economyManager = EconomyManager()
    private var waveManager: WaveManager!
    private var hud: HUD!
    private(set) var gameState = GameState()

    private var enemies: [Walker] = []
    private var bullets: [Bullet] = []
    private var coins: [CoinPickup] = []
    private var pickups: [Pickup] = []
    private let pickupDirector = PickupDirector()

    private var map: MapModel!
    private var wallTextures: WallTextureCache!
    private let renderer = RaycastRenderer()
    private let billboards = BillboardRenderer()
    private let viewmodel = WeaponViewModel()
    private let controls = FPSControls()

    private let worldLayer = SKNode()
    private let controlsLayer = SKNode()

    private var lastUpdateTime: TimeInterval = 0
    /// Scene-local clock that only advances while unpaused — every gameplay
    /// timer runs off this, unchanged from the top-down build.
    private var gameClock: TimeInterval = 0
    private var renderQuality: RenderQuality = SettingsStore.shared.renderQuality

    /// Rolling average frame time, shown in DEBUG. This exists because the
    /// column count is a performance dial and you need a number to tune it
    /// against on a real device.
    private var smoothedFrameTime: TimeInterval = 0
    private var frameTimeLabel: SKLabelNode?

    // MARK: - Run configuration (set before first presentation)

    private var startingMapID: MapID = .original
    private var startingDifficulty: Difficulty = .medium
    private var pendingRestoreState: GameState?
    private var pendingDisplayRound: Int?

    func configureNewRun(mapID: MapID, difficulty: Difficulty) {
        startingMapID = mapID
        startingDifficulty = difficulty
    }

    func configureRestoring(_ state: GameState) {
        pendingRestoreState = state
        startingMapID = state.selectedMap
        startingDifficulty = state.difficulty
    }

    /// didMove(to:) fires on every presentation, including coming back from
    /// the shop or pause menu — this guard keeps setup one-time.
    private var didSetup = false

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !didSetup else { return }
        didSetup = true

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .black
        scaleMode = .resizeFill

        addChild(worldLayer)
        setupMap()
        setupRenderers()
        setupWaveManager()
        setupControls()
        setupHUD()

        if let restoreState = pendingRestoreState {
            applyRestoredState(restoreState)
        }
    }

    private func setupMap() {
        map = MapModel(mapID: startingMapID)
        wallTextures = WallTextureCache(sheetName: map.sheetName, subdirectory: map.sheetSubdirectory)
        wallTextures.preload(tiles: map.usedWallTiles)

        player.position = map.playerStart
        player.facingAngle = 0
    }

    private func setupRenderers() {
        renderer.install(in: worldLayer, sceneSize: size, quality: renderQuality, textures: wallTextures)
        billboards.install(in: worldLayer, quality: renderQuality)
        viewmodel.install(in: self, sceneSize: size)
        viewmodel.setWeapon(player.activeWeapon?.weaponType)
        addCrosshair()
    }

    private func addCrosshair() {
        let crosshair = SKShapeNode(circleOfRadius: 3)
        crosshair.strokeColor = SKColor.white.withAlphaComponent(0.65)
        crosshair.lineWidth = 1.5
        crosshair.fillColor = .clear
        crosshair.zPosition = 600
        addChild(crosshair)
    }

    private func setupControls() {
        addChild(controlsLayer)
        controls.lookSensitivity = CGFloat(SettingsStore.shared.lookSensitivity)
        controls.install(in: controlsLayer, sceneSize: size)
    }

    private func setupHUD() {
        hud = HUD(sceneSize: size)
        addChild(hud)
        refreshHUD()
        hud.showNextRoundButton()
        hud.showShopButton()
        hud.showPauseButton()

        #if DEBUG
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 11
        label.fontColor = .green
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        // Bottom-left, not top-left: the top-left rail is now health bar ->
        // perk icons -> buff pills, and this used to sit on top of the perk
        // row. The move stick is a floating joystick with no resting node,
        // so this corner is otherwise empty.
        label.position = CGPoint(x: -size.width / 2 + 12, y: -size.height / 2 + 52)
        label.zPosition = 3000
        addChild(label)
        frameTimeLabel = label
        #endif
    }

    /// Spawn points come from the map layout's 'S' markers and are
    /// validated against solid geometry — carried over unchanged.
    private func setupWaveManager() {
        waveManager = WaveManager()
        waveManager.delegate = self
        waveManager.difficulty = startingDifficulty
        let bounds = CGRect(
            x: 0, y: -CGFloat(map.layout.rows) * map.cellSize,
            width: CGFloat(map.layout.columns) * map.cellSize,
            height: CGFloat(map.layout.rows) * map.cellSize
        )
        waveManager.configureSpawning(spawnPoints: map.spawnPoints, solidRects: map.solidRects, bounds: bounds)
    }

    private func applyRestoredState(_ state: GameState) {
        player.restorePerks(state.ownedPerks)
        for (index, type) in state.weaponSlots.enumerated() {
            guard let type else { continue }
            let weapon = type.makeWeapon()
            weapon.overclockTier = state.overclockTiers[type] ?? 0
            weapon.refillMagazine()
            player.inventory.equip(weapon, inSlot: index)
        }
        player.inventory.setActiveIndex(state.activeSlot)
        player.inventory.refreshModifiers(perks: player.perks)
        player.restoreHealth(state.playerHealth)
        // Temporary buffs are deliberately absent from GameState and are
        // cleared explicitly here: loading a save always resumes with no
        // Double Damage / Speed Boost running, whatever was active when it
        // was written. Only perks, coins and weapons persist.
        pickupDirector.clearBuffs()
        player.speedBoostMultiplier = 1
        economyManager.setCoins(state.coins)
        waveManager.restoreRound(state.round)
        pendingDisplayRound = state.round
        viewmodel.setWeapon(player.activeWeapon?.weaponType)
        refreshHUD()
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !isPaused, !gameState.isGameOver else { return }

        let deltaTime = min(rawDelta, Balance.maxDeltaTime)
        gameClock += deltaTime
        smoothedFrameTime += (rawDelta - smoothedFrameTime) * 0.1

        updatePlayer(deltaTime: deltaTime)
        map.navGrid.updateFlowField(playerPosition: player.position)
        updateEnemies(deltaTime: deltaTime)
        updateBullets(deltaTime: deltaTime)
        updateCoins(deltaTime: deltaTime)
        updatePickups(deltaTime: deltaTime)
        waveManager.update(currentTime: gameClock)

        renderFrame()
        refreshHUD()
        syncGameState()
        checkPlayerDeath()

        #if DEBUG
        if smoothedFrameTime > 0 {
            frameTimeLabel?.text = String(
                format: "%.1f ms  %.0f fps  cols %d  nodes %d",
                smoothedFrameTime * 1000, 1 / smoothedFrameTime,
                renderer.columnCount, children.count
            )
        }
        #endif
    }

    private func updatePlayer(deltaTime: TimeInterval) {
        // All buff bookkeeping runs off gameClock, which is frozen while
        // paused — so a buff can never tick down inside the shop.
        pickupDirector.expireBuffs(at: gameClock)
        player.speedBoostMultiplier = pickupDirector.speedMultiplier

        player.turn(by: controls.consumeLookDelta())
        let movement = controls.movement
        player.move(forward: movement.dy, strafe: movement.dx, deltaTime: deltaTime, solidRects: map.solidRects)
        viewmodel.update(deltaTime: deltaTime, movementMagnitude: min(movement.length, 1))

        guard let weapon = player.activeWeapon else { return }
        weapon.update(currentTime: gameClock)

        if controls.isFiring, weapon.fire(at: gameClock) {
            fire(weapon: weapon)
            viewmodel.playFireAnimation(for: weapon.weaponType)
            AudioManagerProvider.shared.playSFX("weapon_fire_\(weapon.weaponType.rawValue)")
        }
    }

    // MARK: - Shooting

    /// Instant weapons resolve as hitscans down the crosshair; the two
    /// weapons whose travel time is the point stay as real projectiles.
    private func fire(weapon: Weapon) {
        switch weapon.bulletBehavior {
        case .standard:
            let pellets = max(1, weapon.pelletCount)
            // Double Damage is applied here rather than on the Weapon so
            // the weapon classes and their stats stay untouched.
            let damagePerPellet = weapon.damage * pickupDirector.damageMultiplier / CGFloat(pellets)
            for _ in 0..<pellets {
                // Shotguns are simply several hitscans with angular spread.
                let spread = pellets > 1
                    ? CGFloat.random(in: -weapon.spreadAngle / 2...weapon.spreadAngle / 2)
                    : 0
                let result = HitscanResolver.cast(
                    from: player.position, angle: player.facingAngle + spread,
                    maxRange: weapon.range, map: map, enemies: enemies
                )
                if let enemy = result.enemy {
                    applyDamage(damagePerPellet, to: enemy)
                }
            }
        case .aoe, .chain:
            let direction = CGVector(dx: cos(player.facingAngle), dy: sin(player.facingAngle))
            let bullet = Bullet(
                position: player.position,
                velocity: CGVector(dx: direction.dx * weapon.bulletSpeed, dy: direction.dy * weapon.bulletSpeed),
                damage: weapon.damage * pickupDirector.damageMultiplier,
                maxRange: weapon.range,
                behavior: weapon.bulletBehavior
            )
            bullets.append(bullet)
        }
    }

    private func updateBullets(deltaTime: TimeInterval) {
        var expired: [Bullet] = []
        for bullet in bullets {
            let inRange = bullet.advance(deltaTime: deltaTime)
            // Projectiles stop on walls as well as on enemies.
            if map.isSolid(atWorld: bullet.position) {
                if case .aoe(let radius) = bullet.behavior {
                    explode(at: bullet.position, radius: radius, damage: bullet.damage)
                }
                expired.append(bullet)
                continue
            }
            if let hit = enemies.first(where: {
                $0.isAlive && distance($0.position, bullet.position) < Balance.zombieRadius
            }) {
                resolveHit(bullet: bullet, primary: hit)
                expired.append(bullet)
                continue
            }
            if !inRange {
                if case .aoe(let radius) = bullet.behavior {
                    explode(at: bullet.position, radius: radius, damage: bullet.damage)
                }
                expired.append(bullet)
            }
        }
        guard !expired.isEmpty else { return }
        bullets.removeAll { candidate in expired.contains { $0 === candidate } }
    }

    private func resolveHit(bullet: Bullet, primary: Walker) {
        switch bullet.behavior {
        case .standard:
            applyDamage(bullet.damage, to: primary)
        case .aoe(let radius):
            explode(at: primary.position, radius: radius, damage: bullet.damage)
        case .chain(let maxJumps, let jumpRange, let falloff):
            chainDamage(from: primary, damage: bullet.damage, remainingJumps: maxJumps,
                        jumpRange: jumpRange, falloff: falloff, alreadyHit: [])
        }
    }

    private func explode(at point: CGPoint, radius: CGFloat, damage: CGFloat) {
        for enemy in enemies where enemy.isAlive && distance(enemy.position, point) <= radius {
            applyDamage(damage, to: enemy)
        }
    }

    private func chainDamage(
        from enemy: Walker, damage: CGFloat, remainingJumps: Int,
        jumpRange: CGFloat, falloff: CGFloat, alreadyHit: Set<ObjectIdentifier>
    ) {
        applyDamage(damage, to: enemy)
        guard remainingJumps > 0 else { return }
        var hitSet = alreadyHit
        hitSet.insert(ObjectIdentifier(enemy))
        guard let next = enemies
            .filter({ $0.isAlive && !hitSet.contains(ObjectIdentifier($0)) && distance($0.position, enemy.position) <= jumpRange })
            .min(by: { distance($0.position, enemy.position) < distance($1.position, enemy.position) })
        else { return }
        chainDamage(from: next, damage: damage * falloff, remainingJumps: remainingJumps - 1,
                    jumpRange: jumpRange, falloff: falloff, alreadyHit: hitSet)
    }

    private func applyDamage(_ amount: CGFloat, to enemy: Walker) {
        guard enemy.isAlive else { return }
        enemy.takeDamage(amount)
        if !enemy.isAlive { handleEnemyDeath(enemy) }
    }

    // MARK: - Enemies

    private func updateEnemies(deltaTime: TimeInterval) {
        for enemy in enemies {
            enemy.update(
                currentTime: gameClock, deltaTime: deltaTime,
                playerPosition: player.position, solidRects: map.solidRects, navGrid: map.navGrid
            )
            guard enemy.isAlive else { continue }
            let contactDistance = Balance.zombieRadius + Balance.playerRadius
            if distance(enemy.position, player.position) < contactDistance, enemy.canAttack(at: gameClock) {
                enemy.registerAttack(at: gameClock)
                player.takeDamage(enemy.contactDamage)
            }
        }
        // Dead walkers stay in the list until their death animation has
        // played out, so the billboard finishes instead of popping.
        enemies.removeAll { !$0.isAlive && $0.isDeathAnimationFinished }
    }

    private func handleEnemyDeath(_ enemy: Walker) {
        waveManager.registerDeath(of: enemy)
        spawnCoin(at: enemy.position)
        enemy.startDeathAnimation()
        AudioManagerProvider.shared.playSFX("zombie_death")
    }

    // MARK: - Coins

    private func spawnCoin(at position: CGPoint) {
        coins.append(CoinPickup(value: Balance.coinValue(forRound: waveManager.currentRound), position: position))
    }

    private func updateCoins(deltaTime: TimeInterval) {
        var collected: [CoinPickup] = []
        for coin in coins {
            coin.advanceAnimation(deltaTime: deltaTime)
            let d = distance(coin.position, player.position)
            if d < Balance.coinCollectRadius {
                economyManager.addCoins(coin.value)
                collected.append(coin)
            } else if d < Balance.coinMagnetRadius {
                let dx = player.position.x - coin.position.x
                let dy = player.position.y - coin.position.y
                let dist = max(d, 0.001)
                let step = Balance.coinMagnetSpeed * CGFloat(deltaTime)
                coin.position = CGPoint(x: coin.position.x + dx / dist * step, y: coin.position.y + dy / dist * step)
            }
        }
        guard !collected.isEmpty else { return }
        coins.removeAll { candidate in collected.contains { $0 === candidate } }
    }

    // MARK: - Pickups

    private func updatePickups(deltaTime: TimeInterval) {
        for type in pickupDirector.typesToSpawn(at: gameClock, enemiesAlive: enemies.contains(where: { $0.isAlive })) {
            guard let position = PickupDirector.randomFloorPosition(in: map, awayFrom: player.position) else { continue }
            pickups.append(Pickup(type: type, position: position, spawnClock: gameClock))
        }

        var consumed: [Pickup] = []
        for pickup in pickups {
            pickup.advanceAnimation(deltaTime: deltaTime)
            if pickup.hasExpired(at: gameClock) {
                consumed.append(pickup)
                continue
            }
            if distance(pickup.position, player.position) < Balance.pickupCollectRadius {
                collect(pickup)
                consumed.append(pickup)
            }
        }
        guard !consumed.isEmpty else { return }
        pickups.removeAll { candidate in consumed.contains { $0 === candidate } }
    }

    private func collect(_ pickup: Pickup) {
        pickup.markCollected()
        AudioManagerProvider.shared.playSFX("pickup_\(pickup.type.rawValue)")
        switch pickup.type {
        case .medkit:
            player.heal(fraction: Balance.medkitHealFraction)
        case .doubleDamage, .speedBoost:
            pickupDirector.activateBuff(pickup.type, at: gameClock)
        case .nuke:
            detonateNuke()
        }
    }

    /// Kills every living zombie at once. Each still routes through the
    /// normal death path, so they drop their usual coins and the wave
    /// bookkeeping stays correct — a nuke is a shortcut, not an exception.
    private func detonateNuke() {
        for enemy in enemies where enemy.isAlive {
            enemy.takeDamage(enemy.health)
            handleEnemyDeath(enemy)
        }
    }

    /// Round end: nothing is lost — every coin still on the field is
    /// credited immediately.
    private func collectAllCoins() {
        for coin in coins where !coin.isCollected {
            coin.markCollected()
            economyManager.addCoins(coin.value)
        }
        coins.removeAll()
    }

    // MARK: - Rendering

    private func renderFrame() {
        let camera = RaycastCamera(position: player.position, angle: player.facingAngle)
        renderer.render(camera: camera, map: map)

        var sprites: [BillboardSprite] = []
        sprites.reserveCapacity(enemies.count + coins.count + bullets.count + pickups.count)
        for enemy in enemies {
            guard let texture = enemy.currentTexture else { continue }
            sprites.append(BillboardSprite(worldPosition: enemy.position, texture: texture))
        }
        for coin in coins {
            guard let texture = coin.currentTexture else { continue }
            sprites.append(BillboardSprite(worldPosition: coin.position, texture: texture, heightScale: 0.28, widthScale: 0.28))
        }
        for pickup in pickups {
            guard let texture = pickup.currentTexture else { continue }
            sprites.append(BillboardSprite(
                worldPosition: pickup.position, texture: texture,
                heightScale: 0.32, widthScale: 0.32,
                alpha: pickup.alpha(at: gameClock)
            ))
        }
        if let bulletTexture = Bullet.billboardTexture {
            for bullet in bullets {
                sprites.append(BillboardSprite(worldPosition: bullet.position, texture: bulletTexture, heightScale: 0.15, widthScale: 0.15))
            }
        }

        billboards.render(
            sprites: sprites, camera: camera, map: map,
            depthBuffer: renderer.depthBuffer, columnCount: renderer.columnCount, sceneSize: size
        )
    }

    private func refreshHUD() {
        let displayRound = waveManager.isRoundActive
            ? waveManager.currentRound
            : max(waveManager.currentRound, pendingDisplayRound ?? 0)
        let showSwap = player.inventory.slots[1 - player.inventory.activeIndex] != nil
        controls.setSwapButtonVisible(showSwap)
        hud.update(with: HUDDisplayState(
            health: player.health,
            maxHealth: player.maxHealth,
            round: displayRound,
            ammo: player.activeWeapon?.ammoInMagazine ?? 0,
            magazineSize: player.activeWeapon?.magazineSize ?? 0,
            isReloading: player.activeWeapon?.isReloading ?? false,
            weaponName: player.activeWeapon?.name ?? "—",
            coins: economyManager.coins,
            perks: player.perks,
            // The FPS control layer owns its own swap button, so the HUD's
            // duplicate is suppressed.
            showSwapButton: false,
            activeBuffs: pickupDirector.activeBuffs(at: gameClock)
        ))
    }

    private func syncGameState() {
        gameState.round = waveManager.currentRound
        gameState.isRoundActive = waveManager.isRoundActive
        gameState.playerHealth = player.health
        gameState.playerMaxHealth = player.maxHealth
        gameState.ammoInMagazine = player.activeWeapon?.ammoInMagazine ?? 0
        gameState.magazineSize = player.activeWeapon?.magazineSize ?? 0
        gameState.isReloading = player.activeWeapon?.isReloading ?? false
        gameState.coins = economyManager.coins
        gameState.weaponSlots = player.inventory.slots.map { $0?.weaponType }
        gameState.overclockTiers = Dictionary(
            player.inventory.slots.compactMap { weapon in weapon.map { ($0.weaponType, $0.overclockTier) } },
            uniquingKeysWith: max
        )
        gameState.activeSlot = player.inventory.activeIndex
        gameState.ownedPerks = player.perks
        gameState.selectedMap = startingMapID
        gameState.difficulty = startingDifficulty
    }

    private func checkPlayerDeath() {
        guard !player.isAlive, !gameState.isGameOver else { return }
        gameState.isGameOver = true
        hud.showGameOver(round: waveManager.currentRound, hasAnySave: SaveManager.hasAnySave())
    }

    // MARK: - Settings changes

    /// Called whenever gameplay resumes from the shop or pause menu. Kept
    /// under its original name so ShopScene/PauseMenuScene/SettingsScene
    /// didn't need touching; in first person it re-reads look sensitivity
    /// and render quality instead of swapping control schemes.
    func refreshControlSchemeIfNeeded() {
        controls.lookSensitivity = CGFloat(SettingsStore.shared.lookSensitivity)
        controls.resetInputState()

        let desired = SettingsStore.shared.renderQuality
        guard desired != renderQuality else { return }
        renderQuality = desired
        renderer.configure(sceneSize: size, quality: desired)
        billboards.configure(quality: desired)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let buttonNames = controls.touchesBegan(touches, scene: self)
        for name in buttonNames {
            switch name {
            case FPSControls.reloadButtonName:
                player.activeWeapon?.startReload(at: gameClock)
            case FPSControls.swapButtonName:
                player.inventory.swapActive()
                viewmodel.setWeapon(player.activeWeapon?.weaponType)
            case HUD.nextRoundButtonName:
                startNextRound()
            case HUD.shopButtonName:
                openShop()
            case HUD.pauseButtonName:
                openPauseMenu()
            case HUD.restartButtonName:
                restartGame()
            case HUD.restartFromSaveButtonName:
                restartFromLastSave()
            case HUD.quitButtonName:
                quitToMainMenu()
            default:
                continue
            }
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        controls.touchesMoved(touches, scene: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        controls.touchesEnded(touches, scene: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controls.touchesCancelled(touches, scene: self)
    }

    // MARK: - Flow

    private func startNextRound() {
        hud.hideNextRoundButton()
        hud.hideShopButton()
        waveManager.startNextRound()
        pickupDirector.roundDidStart(at: gameClock)
    }

    private func openShop() {
        controls.resetInputState()
        isPaused = true
        let shop = ShopScene(size: size, gameScene: self)
        shop.scaleMode = scaleMode
        view?.presentScene(shop, transition: .crossFade(withDuration: 0.3))
    }

    private func openPauseMenu() {
        syncGameState()
        controls.resetInputState()
        isPaused = true
        let pause = PauseMenuScene(size: size, gameScene: self)
        pause.scaleMode = scaleMode
        view?.presentScene(pause, transition: .crossFade(withDuration: 0.3))
    }

    private func restartGame() {
        guard let view = view else { return }
        let newScene = GameScene(size: size)
        newScene.configureNewRun(mapID: startingMapID, difficulty: startingDifficulty)
        newScene.scaleMode = scaleMode
        view.presentScene(newScene, transition: .fade(withDuration: 0.4))
    }

    private func restartFromLastSave() {
        guard let slot = SaveManager.mostRecentSlot(),
              let state = SaveManager.loadState(fromSlot: slot),
              let view = view else { return }
        let newScene = GameScene(size: size)
        newScene.configureRestoring(state)
        newScene.scaleMode = scaleMode
        view.presentScene(newScene, transition: .fade(withDuration: 0.4))
    }

    private func quitToMainMenu() {
        guard let view = view else { return }
        let menu = MainMenuScene(size: size)
        menu.scaleMode = scaleMode
        view.presentScene(menu, transition: .fade(withDuration: 0.4))
    }
}

extension GameScene: WaveManagerDelegate {
    func waveManager(_ manager: WaveManager, didSpawn enemy: Enemy) {
        guard let walker = enemy as? Walker else { return }
        enemies.append(walker)
    }

    func waveManagerRoundDidComplete(_ manager: WaveManager, round: Int) {
        enemies.removeAll { !$0.isAlive }
        collectAllCoins()
        // Flat wave-clear bonus, paid the moment the last zombie dies.
        economyManager.addCoins(Balance.waveClearBonus(forRound: round))
        pickupDirector.roundDidEnd()
        pickups.removeAll()
        hud.showNextRoundButton()
        hud.showShopButton()
    }
}
