import SpriteKit

/// One thing to draw as a camera-facing billboard: an enemy, a coin, a
/// projectile. The pack has no directional sprites, so — exactly as in
/// Doom-era engines — the sprite always faces the camera and no attempt is
/// made to fake rotation.
struct BillboardSprite {
    let worldPosition: CGPoint
    let texture: SKTexture
    /// Fraction of a full cell-height the sprite occupies. 1.0 draws it the
    /// same size a wall would be at that distance.
    let heightScale: CGFloat
    /// Multiplied into the width only, for non-square source art.
    let widthScale: CGFloat

    init(worldPosition: CGPoint, texture: SKTexture, heightScale: CGFloat = 1.0, widthScale: CGFloat = 1.0) {
        self.worldPosition = worldPosition
        self.texture = texture
        self.heightScale = heightScale
        self.widthScale = widthScale
    }
}

/// Draws billboards with correct occlusion against walls.
///
/// A single SKSpriteNode can't be partially hidden, so each billboard is
/// cut into vertical slices and every slice is depth-tested against the
/// column of the wall depth buffer it lands on. A zombie half behind a
/// corner therefore loses exactly the slices the wall covers, which is the
/// per-column clipping a software raycaster would do per pixel.
final class BillboardRenderer {
    private let container = SKNode()
    private var slicePool: [SKSpriteNode] = []
    private var sliceCount: Int = 10

    /// Sub-texture slices are references into the parent texture (no pixel
    /// copying), but making them still costs a little, so they're cached
    /// per (texture, slice) forever. The set of source textures is bounded:
    /// 4 zombie variants × their animation frames, plus coins and bullets.
    private struct SliceKey: Hashable {
        let texture: ObjectIdentifier
        let index: Int
        let total: Int
    }
    private var sliceCache: [SliceKey: SKTexture] = [:]

    func install(in parent: SKNode, quality: RenderQuality) {
        container.zPosition = 10
        if container.parent == nil { parent.addChild(container) }
        sliceCount = quality.billboardSlices
    }

    func configure(quality: RenderQuality) {
        sliceCount = quality.billboardSlices
    }

    /// `depthBuffer` holds perpendicular wall distance per column, in the
    /// same cell units the sprite depth is computed in, so the comparison
    /// is direct.
    func render(
        sprites: [BillboardSprite],
        camera: RaycastCamera,
        map: MapModel,
        depthBuffer: [CGFloat],
        columnCount: Int,
        sceneSize: CGSize
    ) {
        var used = 0
        guard columnCount > 0, !depthBuffer.isEmpty else {
            hideUnused(from: 0)
            return
        }

        let columnWidth = sceneSize.width / CGFloat(columnCount)
        let origin = map.gridPosition(ofWorld: camera.position)
        let dirX = cos(camera.angle)
        let dirY = -sin(camera.angle)
        let planeScale = tan(RaycasterConfig.fieldOfView / 2)
        let planeX = -dirY * planeScale
        let planeY = dirX * planeScale

        let determinant = planeX * dirY - dirX * planeY
        guard abs(determinant) > 1e-6 else {
            hideUnused(from: 0)
            return
        }
        let inverseDeterminant = 1 / determinant

        // Project everything first so we can paint far-to-near; nearer
        // billboards then simply get a higher zPosition and overlap
        // correctly without any depth sorting per slice.
        var projected: [(depth: CGFloat, centerX: CGFloat, height: CGFloat, width: CGFloat, texture: SKTexture)] = []
        projected.reserveCapacity(sprites.count)

        for sprite in sprites {
            let spriteGrid = map.gridPosition(ofWorld: sprite.worldPosition)
            let relativeX = spriteGrid.x - origin.x
            let relativeY = spriteGrid.y - origin.y

            let transformX = inverseDeterminant * (dirY * relativeX - dirX * relativeY)
            let depth = inverseDeterminant * (-planeY * relativeX + planeX * relativeY)
            // Anything at or behind the camera plane projects to nonsense.
            guard depth > RaycasterConfig.minimumWallDistance else { continue }

            let centerX = (sceneSize.width / 2) * (transformX / depth)
            let fullHeight = sceneSize.height * RaycasterConfig.wallHeightScale / depth
            let height = fullHeight * sprite.heightScale
            let width = fullHeight * sprite.widthScale

            // Cull sprites entirely off the sides of the screen.
            guard centerX + width / 2 > -sceneSize.width / 2,
                  centerX - width / 2 < sceneSize.width / 2 else { continue }

            projected.append((depth, centerX, height, width, sprite.texture))
        }

        projected.sort { $0.depth > $1.depth }

        for (spriteIndex, item) in projected.enumerated() {
            let sliceWidth = item.width / CGFloat(sliceCount)
            let leftEdge = item.centerX - item.width / 2
            // Full-height billboards stand on the same floor line a wall
            // meets at this distance; shorter ones (coins) rest on it.
            let fullHeight = sceneSize.height * RaycasterConfig.wallHeightScale / item.depth
            let floorLine = camera.pitchOffset - fullHeight / 2
            let centerY = floorLine + item.height / 2

            for slice in 0..<sliceCount {
                let sliceCenterX = leftEdge + (CGFloat(slice) + 0.5) * sliceWidth
                let column = Int((sliceCenterX + sceneSize.width / 2) / columnWidth)
                guard column >= 0, column < depthBuffer.count else { continue }
                // The wall in this column is nearer than the sprite, so
                // this slice is hidden behind it.
                guard depthBuffer[column] > item.depth else { continue }

                let node = sliceNode(at: used)
                used += 1
                node.isHidden = false
                node.texture = sliceTexture(of: item.texture, index: slice)
                node.size = CGSize(width: sliceWidth + 0.5, height: item.height)
                node.position = CGPoint(x: sliceCenterX, y: centerY)
                node.zPosition = CGFloat(spriteIndex)
                node.colorBlendFactor = min(
                    item.depth / RaycasterConfig.shadingFalloffDistance, 1
                ) * RaycasterConfig.maximumShade
            }
        }

        hideUnused(from: used)
    }

    // MARK: - Pooling

    private func sliceNode(at index: Int) -> SKSpriteNode {
        if index < slicePool.count { return slicePool[index] }
        let node = SKSpriteNode()
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        node.color = .black
        node.colorBlendFactor = 0
        container.addChild(node)
        slicePool.append(node)
        return node
    }

    private func hideUnused(from index: Int) {
        guard index < slicePool.count else { return }
        for i in index..<slicePool.count { slicePool[i].isHidden = true }
    }

    private func sliceTexture(of texture: SKTexture, index: Int) -> SKTexture {
        let key = SliceKey(texture: ObjectIdentifier(texture), index: index, total: sliceCount)
        if let cached = sliceCache[key] { return cached }
        let width = 1.0 / CGFloat(sliceCount)
        let slice = SKTexture(
            rect: CGRect(x: CGFloat(index) * width, y: 0, width: width, height: 1),
            in: texture
        )
        slice.filteringMode = .nearest
        sliceCache[key] = slice
        return slice
    }
}
