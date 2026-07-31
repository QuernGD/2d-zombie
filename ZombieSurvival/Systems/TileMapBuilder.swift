import SpriteKit

/// Builds a tile-based arena background from one of the two 32x32 tilesets,
/// replacing Phase 1-3's plain bordered rectangle. Neither tileset ships
/// with a documented tile-index legend, so the column/row picks in Balance
/// (wastelandFloorTile, interiorWallTile, etc.) are a best-effort visual
/// guess — treat them as a starting point to eyeball and adjust in Xcode,
/// not as verified ground truth.
///
/// Wall and obstacle tiles are solid: `build(for:size:)` also returns their
/// world-space rects so GameScene can block player/enemy movement through
/// them (see Geometry.swift's resolveCollision). Floor tiles are never
/// solid.
enum TileMapBuilder {
    struct Result {
        let node: SKNode
        let solidRects: [CGRect]
    }

    private struct Theme {
        let sheetName: String
        let subdirectory: String
        let floor: TileCoord
        let wall: TileCoord
        let obstacleTiles: [TileCoord]
        /// Fractional (x, y) positions within the arena, distinct per map so
        /// the two maps' obstacle arrangement genuinely differs rather than
        /// just reusing the same layout with different textures.
        let obstacleLayout: [(CGFloat, CGFloat)]
    }

    private static func theme(for mapID: MapID) -> Theme {
        switch mapID {
        case .original:
            // "The Yard" -> the outdoor Wasteland tileset.
            return Theme(
                sheetName: "wasteland",
                subdirectory: "Assets/Tiles",
                floor: Balance.wastelandFloorTile,
                wall: Balance.wastelandWallTile,
                obstacleTiles: Balance.wastelandObstacleTiles,
                obstacleLayout: Balance.wastelandObstacleLayout
            )
        case .ashyard:
            // Note: "Ashyard" implies an outdoor space, but it's mapped to
            // the Interior tileset here so the two maps actually look
            // different (Phase 3 only differed by background tint) — the
            // name no longer quite matches the visuals, worth a rename.
            return Theme(
                sheetName: "interior",
                subdirectory: "Assets/Tiles",
                floor: Balance.interiorFloorTile,
                wall: Balance.interiorWallTile,
                obstacleTiles: Balance.interiorObstacleTiles,
                obstacleLayout: Balance.interiorObstacleLayout
            )
        }
    }

    private struct GridCell: Hashable { let col: Int; let row: Int }

    /// Returns a node ready to add to the world layer (tiling `size`,
    /// centered at 0,0 like everything else in GameScene's worldLayer) plus
    /// the world-space rects of every solid (wall/obstacle) tile placed.
    /// Both are empty if the theme's floor tile can't be loaded at all, so
    /// GameScene's plain background-color fallback (set in didMove before
    /// this is called) still shows through with no phantom collision.
    static func build(for mapID: MapID, size: CGSize) -> Result {
        let container = SKNode()
        container.zPosition = 0
        let theme = theme(for: mapID)
        let tileSize = Balance.tileSize

        guard AssetProvider.loadTileTexture(
            sheetName: theme.sheetName, subdirectory: theme.subdirectory,
            tileSize: tileSize, column: theme.floor.column, row: theme.floor.row
        ) != nil else {
            return Result(node: container, solidRects: [])
        }

        let columns = Int(ceil(size.width / CGFloat(tileSize))) + 2
        let rows = Int(ceil(size.height / CGFloat(tileSize))) + 2
        let halfCols = columns / 2
        let halfRows = rows / 2
        let obstacleCells = obstacleCellPositions(columns: columns, rows: rows, layout: theme.obstacleLayout)

        var solidRects: [CGRect] = []
        var obstacleCursor = 0
        for row in 0..<rows {
            for col in 0..<columns {
                let gridX = col - halfCols
                let gridY = row - halfRows
                let isBorder = col == 0 || row == 0 || col == columns - 1 || row == rows - 1
                let isObstacle = !theme.obstacleTiles.isEmpty && obstacleCells.contains(GridCell(col: gridX, row: gridY))

                let tileCoord: TileCoord
                if isBorder {
                    tileCoord = theme.wall
                } else if isObstacle {
                    tileCoord = theme.obstacleTiles[obstacleCursor % theme.obstacleTiles.count]
                    obstacleCursor += 1
                } else {
                    tileCoord = theme.floor
                }

                guard let texture = AssetProvider.loadTileTexture(
                    sheetName: theme.sheetName, subdirectory: theme.subdirectory,
                    tileSize: tileSize, column: tileCoord.column, row: tileCoord.row
                ) else { continue }

                let tilePosition = CGPoint(x: CGFloat(gridX) * CGFloat(tileSize), y: CGFloat(gridY) * CGFloat(tileSize))
                let tile = SKSpriteNode(texture: texture)
                tile.size = CGSize(width: tileSize, height: tileSize)
                tile.position = tilePosition
                container.addChild(tile)

                if isBorder || isObstacle {
                    solidRects.append(CGRect(
                        x: tilePosition.x - CGFloat(tileSize) / 2, y: tilePosition.y - CGFloat(tileSize) / 2,
                        width: CGFloat(tileSize), height: CGFloat(tileSize)
                    ))
                }
            }
        }
        return Result(node: container, solidRects: solidRects)
    }

    /// Converts a theme's fractional (x, y) obstacle layout into concrete
    /// grid cells, scaling with arena size instead of a hardcoded pixel
    /// position that only looks right at one resolution.
    private static func obstacleCellPositions(columns: Int, rows: Int, layout: [(CGFloat, CGFloat)]) -> Set<GridCell> {
        Set(layout.map { fx, fy in
            GridCell(col: Int((fx * CGFloat(columns)).rounded()), row: Int((fy * CGFloat(rows)).rounded()))
        })
    }
}
