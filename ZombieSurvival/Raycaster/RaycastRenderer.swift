import SpriteKit

/// The camera state the renderer needs: where the eye is and which way it
/// points. Kept separate from Player so the renderer has no opinion about
/// inventories, perks or health.
struct RaycastCamera {
    /// World-space position (x right, y up).
    var position: CGPoint
    /// Facing angle in world space: 0 = +x, increasing = counter-clockwise.
    var angle: CGFloat
    /// Vertical screen offset faking a look-up/down. A true raycaster has
    /// no pitch; shifting the horizon is the classic cheat and is all this
    /// does — walls don't foreshorten.
    var pitchOffset: CGFloat = 0
}

/// CPU DDA raycaster drawing into a pool of SKSpriteNodes, one per screen
/// column. No Metal, no shaders — each column is a 1px-wide slice of a wall
/// texture stretched vertically, exactly as Wolfenstein did it.
final class RaycastRenderer {
    private let container = SKNode()
    private let ceilingPlane = SKSpriteNode()
    private let floorPlane = SKSpriteNode()
    private var columns: [SKSpriteNode] = []

    private(set) var columnCount: Int = 0
    private var columnWidth: CGFloat = 1
    private var sceneSize: CGSize = .zero

    /// Perpendicular wall distance (in cells) for each column, written every
    /// frame. Billboards read this to clip themselves against walls.
    private(set) var depthBuffer: [CGFloat] = []

    /// Scratch arrays reused every frame so casting allocates nothing.
    private var rayDistances: [CGFloat] = []
    private var rayTextureX: [Int] = []
    private var rayTiles: [TileCoord] = []
    private var raySideHit: [Bool] = []

    private var textureCache: WallTextureCache?

    // MARK: - Setup

    func install(in parent: SKNode, sceneSize: CGSize, quality: RenderQuality, textures: WallTextureCache) {
        self.textureCache = textures
        container.zPosition = 0
        if container.parent == nil { parent.addChild(container) }

        ceilingPlane.anchorPoint = CGPoint(x: 0.5, y: 0)
        ceilingPlane.color = SKColor(
            red: RaycasterConfig.ceilingColorComponents.0,
            green: RaycasterConfig.ceilingColorComponents.1,
            blue: RaycasterConfig.ceilingColorComponents.2, alpha: 1
        )
        ceilingPlane.zPosition = -2
        floorPlane.anchorPoint = CGPoint(x: 0.5, y: 1)
        floorPlane.color = SKColor(
            red: RaycasterConfig.floorColorComponents.0,
            green: RaycasterConfig.floorColorComponents.1,
            blue: RaycasterConfig.floorColorComponents.2, alpha: 1
        )
        floorPlane.zPosition = -2
        if ceilingPlane.parent == nil { container.addChild(ceilingPlane) }
        if floorPlane.parent == nil { container.addChild(floorPlane) }

        configure(sceneSize: sceneSize, quality: quality)
    }

    /// (Re)builds the column pool. Called on install and whenever the
    /// resolution setting changes; never per frame.
    func configure(sceneSize: CGSize, quality: RenderQuality) {
        self.sceneSize = sceneSize
        // Never make a column narrower than a point — past that we'd be
        // paying for nodes finer than the display can show.
        let requested = min(quality.columnCount, Int(sceneSize.width))
        columnCount = max(requested, 1)
        columnWidth = sceneSize.width / CGFloat(columnCount)

        ceilingPlane.size = CGSize(width: sceneSize.width, height: sceneSize.height)
        floorPlane.size = CGSize(width: sceneSize.width, height: sceneSize.height)

        depthBuffer = Array(repeating: .greatestFiniteMagnitude, count: columnCount)
        rayDistances = Array(repeating: 0, count: columnCount)
        rayTextureX = Array(repeating: 0, count: columnCount)
        rayTiles = Array(repeating: TileCoord(column: 0, row: 0), count: columnCount)
        raySideHit = Array(repeating: false, count: columnCount)

        for node in columns { node.removeFromParent() }
        columns.removeAll(keepingCapacity: true)
        columns.reserveCapacity(columnCount)
        for index in 0..<columnCount {
            let node = SKSpriteNode()
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = CGPoint(x: -sceneSize.width / 2 + (CGFloat(index) + 0.5) * columnWidth, y: 0)
            node.color = .black
            node.colorBlendFactor = 0
            node.zPosition = 0
            node.isHidden = true
            container.addChild(node)
            columns.append(node)
        }
    }

    // MARK: - Frame

    func render(camera: RaycastCamera, map: MapModel) {
        ceilingPlane.position = CGPoint(x: 0, y: camera.pitchOffset)
        floorPlane.position = CGPoint(x: 0, y: camera.pitchOffset)

        castAll(camera: camera, map: map)
        drawColumns(camera: camera)
    }

    /// DDA in grid space, where a cell is exactly 1 unit so stepping is a
    /// pair of additions and no division per step.
    private func castAll(camera: RaycastCamera, map: MapModel) {
        let origin = map.gridPosition(ofWorld: camera.position)
        // Grid y grows *downward* while world y grows upward, hence the
        // negated sine: this is the only place the two conventions meet.
        let dirX = cos(camera.angle)
        let dirY = -sin(camera.angle)
        // Camera plane is `dir` rotated 90°, scaled by tan(fov/2). This
        // orientation is what makes screen-left correspond to the player's
        // left rather than mirroring the world.
        let planeScale = tan(RaycasterConfig.fieldOfView / 2)
        let planeX = -dirY * planeScale
        let planeY = dirX * planeScale

        for column in 0..<columnCount {
            let cameraX = 2 * CGFloat(column) / CGFloat(columnCount) - 1
            let rayDirX = dirX + planeX * cameraX
            let rayDirY = dirY + planeY * cameraX

            var mapX = Int(floor(origin.x))
            var mapY = Int(floor(origin.y))

            let deltaDistX = rayDirX == 0 ? CGFloat.greatestFiniteMagnitude : abs(1 / rayDirX)
            let deltaDistY = rayDirY == 0 ? CGFloat.greatestFiniteMagnitude : abs(1 / rayDirY)

            var stepX = 1
            var stepY = 1
            var sideDistX: CGFloat
            var sideDistY: CGFloat

            if rayDirX < 0 {
                stepX = -1
                sideDistX = (origin.x - CGFloat(mapX)) * deltaDistX
            } else {
                sideDistX = (CGFloat(mapX) + 1 - origin.x) * deltaDistX
            }
            if rayDirY < 0 {
                stepY = -1
                sideDistY = (origin.y - CGFloat(mapY)) * deltaDistY
            } else {
                sideDistY = (CGFloat(mapY) + 1 - origin.y) * deltaDistY
            }

            var hitVerticalSide = false
            var hit = false
            var depth = 0
            while !hit && depth < RaycasterConfig.maximumRayDepth {
                if sideDistX < sideDistY {
                    sideDistX += deltaDistX
                    mapX += stepX
                    hitVerticalSide = true
                } else {
                    sideDistY += deltaDistY
                    mapY += stepY
                    hitVerticalSide = false
                }
                depth += 1
                if map.isSolid(column: mapX, row: mapY) { hit = true }
            }

            // Perpendicular distance, not euclidean — this *is* the fisheye
            // correction (it's algebraically the same as multiplying the
            // euclidean distance by cos(rayAngle - playerAngle), just
            // without the extra trig per column).
            let perpendicular: CGFloat = hitVerticalSide
                ? (sideDistX - deltaDistX)
                : (sideDistY - deltaDistY)
            let distance = max(perpendicular, RaycasterConfig.minimumWallDistance)

            // Exact hit point along the wall face, mapped to a texture strip.
            let wallHit: CGFloat = hitVerticalSide
                ? origin.y + distance * rayDirY
                : origin.x + distance * rayDirX
            var wallFraction = wallHit - floor(wallHit)
            // Mirror the two faces you see from "behind" so texture detail
            // doesn't read as flipped when you walk around a block.
            if hitVerticalSide, rayDirX > 0 { wallFraction = 1 - wallFraction }
            if !hitVerticalSide, rayDirY < 0 { wallFraction = 1 - wallFraction }

            let stripCount = textureCache?.stripCount ?? Balance.tileSize
            var textureX = Int(wallFraction * CGFloat(stripCount))
            textureX = min(max(textureX, 0), stripCount - 1)

            rayDistances[column] = distance
            rayTextureX[column] = textureX
            rayTiles[column] = map.wallTexture(column: mapX, row: mapY)
            raySideHit[column] = hitVerticalSide
            depthBuffer[column] = distance
        }
    }

    private func drawColumns(camera: RaycastCamera) {
        let projectionHeight = sceneSize.height * RaycasterConfig.wallHeightScale
        let maximumHeight = sceneSize.height * RaycasterConfig.maximumColumnHeightMultiplier

        for index in 0..<columnCount {
            let node = columns[index]
            guard let strips = textureCache?.strips(for: rayTiles[index]) else {
                node.isHidden = true
                continue
            }

            let distance = rayDistances[index]
            let height = min(projectionHeight / distance, maximumHeight)

            node.isHidden = false
            node.texture = strips[min(rayTextureX[index], strips.count - 1)]
            node.size = CGSize(width: columnWidth, height: height)
            node.position.y = camera.pitchOffset

            var shade = min(distance / RaycasterConfig.shadingFalloffDistance, 1) * RaycasterConfig.maximumShade
            // Walls facing north/south get a flat extra darkening so edges
            // between two perpendicular faces stay readable without lights.
            if !raySideHit[index] { shade = min(shade + RaycasterConfig.sideFaceShade, 1) }
            node.colorBlendFactor = shade
        }
    }
}
