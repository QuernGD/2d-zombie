import SpriteKit

/// Turns a hand-written ASCII layout (MapLayouts) into a rendered arena:
/// tile sprites, the solid rects that block movement, the spawn points
/// WaveManager uses, and the NavGrid enemies path over.
///
/// The layout is a fixed grid, so tiles are scaled to fit the whole arena
/// on screen (there's no scrolling camera) — every designed cell is always
/// visible and reachable regardless of device size.
enum TileMapBuilder {
    struct Result {
        let node: SKNode
        let solidRects: [CGRect]
        let spawnPoints: [CGPoint]
        let navGrid: NavGrid
        /// World rect covering the whole layout, used to bound the player.
        let worldRect: CGRect
    }

    private struct Theme {
        let sheetName: String
        let subdirectory: String
        let floorTile: TileCoord
        let floorVariants: [TileCoord]
        let wallTile: TileCoord
        let propTiles: [TileCoord]
        /// Top-left corners of 2x2 sprites (vehicles) used to draw 2x2
        /// obstacle clusters as one object instead of four loose props.
        let vehicleOrigins: [TileCoord]
    }

    private static func theme(for mapID: MapID) -> Theme {
        switch mapID {
        case .original:
            return Theme(
                sheetName: "wasteland", subdirectory: "Assets/Tiles",
                floorTile: Balance.wastelandFloorTile,
                floorVariants: Balance.wastelandFloorVariants,
                wallTile: Balance.wastelandWallTile,
                propTiles: Balance.wastelandPropTiles,
                vehicleOrigins: Balance.wastelandVehicleOrigins
            )
        case .facility:
            return Theme(
                sheetName: "interior", subdirectory: "Assets/Tiles",
                floorTile: Balance.interiorFloorTile,
                floorVariants: Balance.interiorFloorVariants,
                wallTile: Balance.interiorWallTile,
                propTiles: Balance.interiorPropTiles,
                vehicleOrigins: Balance.interiorVehicleOrigins
            )
        }
    }

    // MARK: - Build

    static func build(for mapID: MapID, size: CGSize) -> Result {
        let theme = theme(for: mapID)
        let layout = MapLayouts.parse(MapLayouts.rows(for: mapID))

        // Fit the whole layout on screen. `min` (not `max`) so nothing
        // designed ever ends up off-screen where the player can't see the
        // zombie walking at them; the leftover margin is just background.
        let renderTileSize = min(size.width / CGFloat(layout.columns), size.height / CGFloat(layout.rows))
        let mapWidth = CGFloat(layout.columns) * renderTileSize
        let mapHeight = CGFloat(layout.rows) * renderTileSize
        let worldRect = CGRect(x: -mapWidth / 2, y: -mapHeight / 2, width: mapWidth, height: mapHeight)
        // Centre of the top-left cell, in a scene whose origin is centred.
        let topLeftCenter = CGPoint(
            x: worldRect.minX + renderTileSize / 2,
            y: worldRect.maxY - renderTileSize / 2
        )

        let container = SKNode()
        container.zPosition = 0

        let navGrid = NavGrid(layout: layout, tileSize: renderTileSize, topLeftCenter: topLeftCenter)
        if !navGrid.isFullyConnected() {
            let message = "Map \(mapID.rawValue): walkable space is NOT fully connected — some area is sealed off and enemies can never path there. Fix the layout in MapLayouts.swift."
            print("⚠️ \(message)")
            assertionFailure(message)
        }

        var solidRects: [CGRect] = []
        let vehicleCells = vehicleClusterCells(in: layout, theme: theme)

        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let cell = layout.cell(column: column, row: row)
                let position = navGrid.worldPosition(column: column, row: row)

                if cell.isSolid {
                    solidRects.append(CGRect(
                        x: position.x - renderTileSize / 2, y: position.y - renderTileSize / 2,
                        width: renderTileSize, height: renderTileSize
                    ))
                }

                // Cells belonging to a 2x2 vehicle are drawn by the cluster
                // pass below, but still get floor underneath so nothing
                // shows through a transparent corner of the sprite.
                let coordinate = TileCoord(column: column, row: row)
                let baseTile: TileCoord
                switch cell {
                case .wall:
                    baseTile = theme.wallTile
                case .obstacle where vehicleCells[coordinate] == nil:
                    baseTile = prop(for: coordinate, theme: theme)
                case .obstacle, .floor, .spawn:
                    baseTile = floor(for: coordinate, theme: theme)
                }
                addTile(baseTile, at: position, size: renderTileSize, theme: theme, to: container, zPosition: 0)
            }
        }

        // Second pass: 2x2 obstacle clusters drawn as single vehicles.
        for (coordinate, sheetCoordinate) in vehicleCells {
            let position = navGrid.worldPosition(column: coordinate.column, row: coordinate.row)
            addTile(sheetCoordinate, at: position, size: renderTileSize, theme: theme, to: container, zPosition: 1)
        }

        let spawnPoints = layout.spawnCells.map { navGrid.worldPosition(column: $0.column, row: $0.row) }
        return Result(node: container, solidRects: solidRects, spawnPoints: spawnPoints, navGrid: navGrid, worldRect: worldRect)
    }

    // MARK: - Tile selection

    /// Deterministic per-cell pick (rather than `randomElement()`) so a
    /// given map always looks identical run to run — a map that reshuffles
    /// its ground texture every time you restart looks like a glitch.
    private static func floor(for coordinate: TileCoord, theme: Theme) -> TileCoord {
        guard !theme.floorVariants.isEmpty else { return theme.floorTile }
        return theme.floorVariants[hash(coordinate) % theme.floorVariants.count]
    }

    private static func prop(for coordinate: TileCoord, theme: Theme) -> TileCoord {
        guard !theme.propTiles.isEmpty else { return theme.wallTile }
        return theme.propTiles[hash(coordinate) % theme.propTiles.count]
    }

    private static func hash(_ coordinate: TileCoord) -> Int {
        abs(coordinate.column &* 73856093 ^ coordinate.row &* 19349663) % 100_000
    }

    /// Finds 2x2 blocks of obstacle cells and maps every cell in them to
    /// the matching cell of a 2x2 vehicle sprite. Returns an empty map if
    /// the theme has no vehicle art, in which case everything falls back to
    /// single-tile props.
    private static func vehicleClusterCells(in layout: ParsedMapLayout, theme: Theme) -> [TileCoord: TileCoord] {
        guard !theme.vehicleOrigins.isEmpty else { return [:] }

        var result: [TileCoord: TileCoord] = [:]
        var consumed: Set<TileCoord> = []
        var vehicleIndex = 0

        for row in 0..<(max(layout.rows - 1, 0)) {
            for column in 0..<(max(layout.columns - 1, 0)) {
                let block = [
                    TileCoord(column: column, row: row), TileCoord(column: column + 1, row: row),
                    TileCoord(column: column, row: row + 1), TileCoord(column: column + 1, row: row + 1)
                ]
                guard block.allSatisfy({ layout.cell(column: $0.column, row: $0.row) == .obstacle }),
                      block.allSatisfy({ !consumed.contains($0) })
                else { continue }

                let origin = theme.vehicleOrigins[vehicleIndex % theme.vehicleOrigins.count]
                vehicleIndex += 1
                for (offset, coordinate) in block.enumerated() {
                    consumed.insert(coordinate)
                    result[coordinate] = TileCoord(
                        column: origin.column + (offset % 2),
                        row: origin.row + (offset / 2)
                    )
                }
            }
        }
        return result
    }

    private static func addTile(
        _ sheetCoordinate: TileCoord, at position: CGPoint, size: CGFloat,
        theme: Theme, to container: SKNode, zPosition: CGFloat
    ) {
        guard let texture = AssetProvider.loadTileTexture(
            sheetName: theme.sheetName, subdirectory: theme.subdirectory,
            tileSize: Balance.tileSize, column: sheetCoordinate.column, row: sheetCoordinate.row
        ) else { return }

        let tile = SKSpriteNode(texture: texture)
        // +1 hides the hairline seams that show between neighbouring tiles
        // when renderTileSize lands on a fractional point value.
        tile.size = CGSize(width: size + 1, height: size + 1)
        tile.position = position
        tile.zPosition = zPosition
        container.addChild(tile)
    }
}
