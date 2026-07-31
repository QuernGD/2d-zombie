import SpriteKit
import UIKit

final class GameScene: SKScene {
    private(set) var player: Player!
    private(set) var economyManager = EconomyManager()
    private var controlScheme: ControlScheme = ControlSchemeFactory.make(GameState().controlSchemeType)
    private var waveManager: WaveManager!
    private var hud: HUD!
    private var gameState = GameState()

    private var bullets: [Bullet] = []
    private var enemies: [Walker] = []
    private var coins: [CoinPickup] = []

    private var lastUpdateTime: TimeInterval = 0
    /// Scene-local clock that only advances while unpaused. Every gameplay
    /// timer (fire rate, reload, attack cooldown, spawn interval) is driven
    /// off this instead of SpriteKit's real-time `currentTime`, so pausing
    /// for the shop can never hand a timer a giant catch-up tick.
    private var gameClock: TimeInterval = 0

    private let worldLayer = SKNode()
    private let controlsLayer = SKNode()

    /// didMove(to:) fires every time this scene is presented — including
    /// re-presenting this exact instance after the shop closes. Without this
    /// guard, returning from the shop would rebuild Player/WaveManager/HUD
    /// from scratch and silently wipe round progress, health, and weapons.
    private var didSetup = false

    override func didMove(to view: SKView) {
        guard !didSetup else { return }
        didSetup = true

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.08, green: 0.10, blue: 0.08, alpha: 1.0)
        scaleMode = .resizeFill

        addChild(worldLayer)
        setupArena()
        setupPlayer()
        setupWaveManager()
        setupControls()
        setupHUD()
    }

    private func setupArena() {
        let border = SKShapeNode(rectOf: size)
        border.strokeColor = SKColor.white.withAlphaComponent(0.3)
        border.lineWidth = 3
        border.fillColor = .clear
        border.zPosition = 0
        worldLayer.addChild(border)
    }

    private func setupPlayer() {
        player = Player()
        player.position = .zero
        worldLayer.addChild(player)
    }

    private func setupControls() {
        addChild(controlsLayer)
        controlScheme.install(in: controlsLayer, sceneSize: size)
    }

    private func setupHUD() {
        hud = HUD(sceneSize: size)
        addChild(hud)
        refreshHUD()
        hud.showNextRoundButton() // Round 1 also waits for the player to tap "Next Round".
        hud.showShopButton()
    }

    private func setupWaveManager() {
        let inset: CGFloat = 60
        let halfWidth = size.width / 2 - inset
        let halfHeight = size.height / 2 - inset
        let spawnPoints = [
            CGPoint(x: -halfWidth, y: halfHeight), CGPoint(x: 0, y: halfHeight), CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: -halfHeight), CGPoint(x: 0, y: -halfHeight), CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: -halfWidth, y: 0), CGPoint(x: halfWidth, y: 0)
        ]
        waveManager = WaveManager(spawnPoints: spawnPoints)
        waveManager.delegate = self
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        // While the shop is open, isPaused (SKScene's own flag) stops
        // SpriteKit from calling update() at all; this guard is a second,
        // explicit line of defense matching that same intent.
        guard !isPaused, !gameState.isGameOver else { return }

        // Clamped so a pause (or any frame hitch) can never teleport enemies
        // or hand a timer a giant catch-up tick.
        let deltaTime = min(rawDelta, Balance.maxDeltaTime)
        gameClock += deltaTime

        controlScheme.update(currentTime: gameClock, playerPosition: player.position) { [weak self] in
            self?.nearestAliveEnemy()?.position
        }

        updatePlayer(deltaTime: deltaTime, currentTime: gameClock)
        updateBullets(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime, currentTime: gameClock)
        updateCoins(deltaTime: deltaTime)
        waveManager.update(currentTime: gameClock)
        refreshHUD()
        syncGameState()
        checkPlayerDeath()
    }

    private func nearestAliveEnemy() -> Walker? {
        enemies.filter { $0.isAlive }
            .min { distance($0.position, player.position) < distance($1.position, player.position) }
    }

    private func updatePlayer(deltaTime: TimeInterval, currentTime: TimeInterval) {
        let bounds = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        player.move(by: controlScheme.movementVector, deltaTime: deltaTime, bounds: bounds)

        let aimVector = controlScheme.aimVector
        if !aimVector.isZero {
            player.setFacing(angle: atan2(aimVector.dy, aimVector.dx))
        }

        guard let weapon = player.activeWeapon else { return }
        weapon.update(currentTime: currentTime)

        if controlScheme.isFiring, !aimVector.isZero, weapon.fire(at: currentTime) {
            spawnShots(direction: aimVector, weapon: weapon)
        }
    }

    private func spawnShots(direction: CGVector, weapon: Weapon) {
        let baseAngle = atan2(direction.dy, direction.dx)
        let count = max(1, weapon.pelletCount)
        let perShotDamage = weapon.damage / CGFloat(count)

        for _ in 0..<count {
            let spread = count > 1 ? CGFloat.random(in: -weapon.spreadAngle / 2...weapon.spreadAngle / 2) : 0
            let angle = baseAngle + spread
            let shotVector = CGVector(dx: cos(angle), dy: sin(angle))
            let velocity = CGVector(dx: shotVector.dx * weapon.bulletSpeed, dy: shotVector.dy * weapon.bulletSpeed)
            let bullet = Bullet(velocity: velocity, damage: perShotDamage, maxRange: weapon.range, behavior: weapon.bulletBehavior)
            bullet.position = player.position
            worldLayer.addChild(bullet)
            bullets.append(bullet)
        }
    }

    private func updateBullets(deltaTime: TimeInterval) {
        var expired: [Bullet] = []
        for bullet in bullets {
            let stillInRange = bullet.advance(deltaTime: deltaTime)
            if let hitEnemy = enemies.first(where: { $0.isAlive && distance($0.position, bullet.position) < Balance.zombieRadius + Balance.pistolBulletRadius }) {
                resolveHit(bullet: bullet, primary: hitEnemy)
                expired.append(bullet)
                continue
            }
            if !stillInRange {
                if case .aoe(let radius) = bullet.behavior {
                    explode(at: bullet.position, radius: radius, damage: bullet.damage)
                }
                expired.append(bullet)
            }
        }
        guard !expired.isEmpty else { return }
        for bullet in expired {
            bullet.removeFromParent()
        }
        bullets.removeAll { candidate in expired.contains { $0 === candidate } }
    }

    private func resolveHit(bullet: Bullet, primary: Walker) {
        switch bullet.behavior {
        case .standard:
            applyDamage(bullet.damage, to: primary)
        case .aoe(let radius):
            explode(at: primary.position, radius: radius, damage: bullet.damage)
        case .chain(let maxJumps, let jumpRange, let falloff):
            chainDamage(from: primary, damage: bullet.damage, remainingJumps: maxJumps, jumpRange: jumpRange, falloff: falloff, alreadyHit: [])
        }
    }

    private func explode(at point: CGPoint, radius: CGFloat, damage: CGFloat) {
        for enemy in enemies where enemy.isAlive && distance(enemy.position, point) <= radius {
            applyDamage(damage, to: enemy)
        }
        let ring = SKShapeNode(circleOfRadius: 4)
        ring.position = point
        ring.strokeColor = .systemOrange
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 80
        worldLayer.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: radius / 4, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func chainDamage(from enemy: Walker, damage: CGFloat, remainingJumps: Int, jumpRange: CGFloat, falloff: CGFloat, alreadyHit: Set<ObjectIdentifier>) {
        applyDamage(damage, to: enemy)
        guard remainingJumps > 0 else { return }

        var hitSet = alreadyHit
        hitSet.insert(ObjectIdentifier(enemy))
        guard let next = enemies
            .filter({ $0.isAlive && !hitSet.contains(ObjectIdentifier($0)) && distance($0.position, enemy.position) <= jumpRange })
            .min(by: { distance($0.position, enemy.position) < distance($1.position, enemy.position) })
        else { return }

        let arc = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: enemy.position)
        path.addLine(to: next.position)
        arc.path = path
        arc.strokeColor = .cyan
        arc.lineWidth = 2
        arc.zPosition = 80
        worldLayer.addChild(arc)
        arc.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))

        chainDamage(from: next, damage: damage * falloff, remainingJumps: remainingJumps - 1, jumpRange: jumpRange, falloff: falloff, alreadyHit: hitSet)
    }

    private func applyDamage(_ amount: CGFloat, to enemy: Walker) {
        enemy.takeDamage(amount)
        if !enemy.isAlive {
            handleEnemyDeath(enemy)
        }
    }

    private func updateEnemies(deltaTime: TimeInterval, currentTime: TimeInterval) {
        for enemy in enemies where enemy.isAlive {
            enemy.update(currentTime: currentTime, deltaTime: deltaTime, playerPosition: player.position)
            let contactDistance = Balance.zombieRadius + Balance.playerRadius
            if distance(enemy.position, player.position) < contactDistance, enemy.canAttack(at: currentTime) {
                enemy.registerAttack(at: currentTime)
                player.takeDamage(enemy.contactDamage)
            }
        }
    }

    private func handleEnemyDeath(_ enemy: Walker) {
        waveManager.registerDeath(of: enemy)
        spawnCoin(at: enemy.position)

        let shrink = SKAction.scale(to: 0, duration: Balance.zombieDeathEffectDuration)
        let fade = SKAction.fadeOut(withDuration: Balance.zombieDeathEffectDuration)
        enemy.run(.sequence([.group([shrink, fade]), .removeFromParent()]))
    }

    // MARK: - Coins

    private func spawnCoin(at position: CGPoint) {
        let coin = CoinPickup(value: Balance.coinValue(forRound: waveManager.currentRound))
        coin.position = position
        worldLayer.addChild(coin)
        coins.append(coin)
    }

    private func updateCoins(deltaTime: TimeInterval) {
        var collected: [CoinPickup] = []
        for coin in coins {
            let d = distance(coin.position, player.position)
            if d < Balance.coinCollectRadius {
                economyManager.addCoins(coin.value)
                coin.removeFromParent()
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

    /// Round end: nothing is lost. Every coin still on the field is credited
    /// immediately and sent flying to the player purely as a visual flourish.
    private func collectAllCoins() {
        for coin in coins where !coin.isCollected {
            coin.markCollected()
            economyManager.addCoins(coin.value)
            let move = SKAction.move(to: player.position, duration: Balance.coinRoundEndFlyDuration)
            move.timingMode = .easeIn
            coin.run(.sequence([move, .fadeOut(withDuration: 0.05), .removeFromParent()]))
        }
        coins.removeAll()
    }

    private func refreshHUD() {
        hud.update(with: HUDDisplayState(
            health: player.health,
            maxHealth: player.maxHealth,
            round: waveManager.currentRound,
            ammo: player.activeWeapon?.ammoInMagazine ?? 0,
            magazineSize: player.activeWeapon?.magazineSize ?? 0,
            isReloading: player.activeWeapon?.isReloading ?? false,
            weaponName: player.activeWeapon?.name ?? "—",
            coins: economyManager.coins,
            perks: player.perks,
            showSwapButton: player.inventory.slots[1 - player.inventory.activeIndex] != nil
        ))
    }

    /// Not wired to any save/load trigger yet (that's Phase 3) — this is the
    /// designated integration point: a fresh, accurate GameState on demand
    /// from the live objects that are the real source of truth.
    private func syncGameState() {
        gameState.round = waveManager.currentRound
        gameState.isRoundActive = waveManager.isRoundActive
        gameState.playerHealth = player.health
        gameState.playerMaxHealth = player.maxHealth
        gameState.ammoInMagazine = player.activeWeapon?.ammoInMagazine ?? 0
        gameState.magazineSize = player.activeWeapon?.magazineSize ?? 0
        gameState.isReloading = player.activeWeapon?.isReloading ?? false
        gameState.coins = economyManager.coins
        gameState.ownedWeapons = Array(player.inventory.ownedTypes)
        // Mystery Crate can legitimately roll a type the player already owns
        // into the other slot, so two slots can share a WeaponType — keep
        // the higher tier rather than crashing on the duplicate key.
        gameState.overclockTiers = Dictionary(
            player.inventory.slots.compactMap { weapon in weapon.map { ($0.weaponType, $0.overclockTier) } },
            uniquingKeysWith: max
        )
        gameState.activeSlot = player.inventory.activeIndex
        gameState.ownedPerks = player.perks
    }

    private func checkPlayerDeath() {
        guard !player.isAlive, !gameState.isGameOver else { return }
        gameState.isGameOver = true
        hud.showGameOver(round: waveManager.currentRound)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let node = atPoint(touch.location(in: self))
            switch node.name {
            case HUD.nextRoundButtonName:
                startNextRound()
                return
            case HUD.shopButtonName:
                openShop()
                return
            case HUD.swapWeaponButtonName:
                player.inventory.swapActive()
                return
            case HUD.restartButtonName:
                restartGame()
                return
            case HUD.mainMenuButtonName:
                // Stubbed: no main menu exists yet in this phase.
                return
            default:
                continue
            }
        }
        controlScheme.touchesBegan(touches, scene: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        controlScheme.touchesMoved(touches, scene: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        controlScheme.touchesEnded(touches, scene: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controlScheme.touchesCancelled(touches, scene: self)
    }

    private func startNextRound() {
        hud.hideNextRoundButton()
        hud.hideShopButton()
        waveManager.startNextRound()
    }

    private func openShop() {
        isPaused = true
        let shop = ShopScene(size: size, gameScene: self)
        shop.scaleMode = scaleMode
        view?.presentScene(shop, transition: .crossFade(withDuration: 0.3))
    }

    private func restartGame() {
        guard let view = view else { return }
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        view.presentScene(newScene, transition: .fade(withDuration: 0.4))
    }
}

extension GameScene: WaveManagerDelegate {
    func waveManager(_ manager: WaveManager, didSpawn enemy: Enemy) {
        guard let walker = enemy as? Walker else { return }
        worldLayer.addChild(walker)
        enemies.append(walker)
    }

    func waveManagerRoundDidComplete(_ manager: WaveManager, round: Int) {
        enemies.removeAll { !$0.isAlive }
        collectAllCoins()
        hud.showNextRoundButton()
        hud.showShopButton()
    }
}
