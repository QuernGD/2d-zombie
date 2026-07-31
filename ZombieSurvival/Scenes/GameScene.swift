import SpriteKit
import UIKit

final class GameScene: SKScene {
    private var player: Player!
    private var controlScheme: ControlScheme = ControlSchemeFactory.make(GameState().controlSchemeType)
    private var waveManager: WaveManager!
    private var hud: HUD!
    private var gameState = GameState()

    private var bullets: [Bullet] = []
    private var enemies: [Walker] = []

    private var lastUpdateTime: TimeInterval = 0
    private let worldLayer = SKNode()
    private let controlsLayer = SKNode()

    override func didMove(to view: SKView) {
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
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !gameState.isGameOver else { return }

        controlScheme.update(currentTime: currentTime, playerPosition: player.position) { [weak self] in
            self?.nearestAliveEnemy()?.position
        }

        updatePlayer(deltaTime: deltaTime, currentTime: currentTime)
        updateBullets(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime, currentTime: currentTime)
        waveManager.update(currentTime: currentTime)
        refreshHUD()
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

        player.pistol.update(currentTime: currentTime)

        if controlScheme.isFiring, !aimVector.isZero, player.pistol.fire(at: currentTime) {
            spawnBullet(direction: aimVector)
        }
    }

    private func spawnBullet(direction: CGVector) {
        let normalized = direction.normalized
        guard !normalized.isZero else { return }
        let velocity = CGVector(dx: normalized.dx * player.pistol.bulletSpeed, dy: normalized.dy * player.pistol.bulletSpeed)
        let bullet = Bullet(velocity: velocity, damage: player.pistol.damage, maxRange: player.pistol.range)
        bullet.position = player.position
        worldLayer.addChild(bullet)
        bullets.append(bullet)
    }

    private func updateBullets(deltaTime: TimeInterval) {
        var expired: [Bullet] = []
        for bullet in bullets {
            guard bullet.advance(deltaTime: deltaTime) else {
                expired.append(bullet)
                continue
            }
            if let hit = enemies.first(where: { $0.isAlive && distance($0.position, bullet.position) < Balance.zombieRadius + Balance.pistolBulletRadius }) {
                hit.takeDamage(bullet.damage)
                expired.append(bullet)
                if !hit.isAlive {
                    handleEnemyDeath(hit)
                }
            }
        }
        guard !expired.isEmpty else { return }
        for bullet in expired {
            bullet.removeFromParent()
        }
        bullets.removeAll { candidate in expired.contains { $0 === candidate } }
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
        enemy.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    private func refreshHUD() {
        hud.update(
            health: player.health,
            maxHealth: player.maxHealth,
            round: waveManager.currentRound,
            ammo: player.pistol.ammoInMagazine,
            magazineSize: player.pistol.magazineSize,
            isReloading: player.pistol.isReloading
        )
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
        waveManager.startNextRound()
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
        hud.showNextRoundButton()
    }
}
