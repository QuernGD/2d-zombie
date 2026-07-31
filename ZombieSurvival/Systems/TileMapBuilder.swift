import SpriteKit

/// Builds a tile-based arena background from one of the two 32x32 tilesets,
/// replacing Phase 1-3's plain bordered rectangle. Neither tileset ships
/// with a documented tile-index legend, so the column/row picks in Balance
/// (wastelandFloorTile, interiorWallTile, etc.) are a best-effort visual
/// guess — treat them as a starting point to eyeball and adjust in Xcode,
/// not as verified ground truth.
///
/// Purely decorative: it lays down floor/wall/obstacle tiles but adds no
/// collision, so player/enemy movement is unaffected by walls or obstacles.
enum TileMapBuilder {
    private struct Theme {
        let sheetName: String
        let subdirectory: String
        let floor: TileCoord
        let wall: TileCoord
        let obstacles: [TileCoord]
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
                obstacles: Balance.wastelandObstacleTiles
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
                obstacles: Balance.interiorObstacleTiles
            )
        }
    }

    private struct GridCell: Hashable { let col: Int; let row: Int }

    /// Returns a node ready to add to the world layer, tiling `size` (the
    /// scene's full extent, centered at 0,0 like everything else in
    /// GameScene's worldLayer). Empty (no children) if the theme's floor
    /// tile can't be loaded at all, so GameScene's plain background-color
    /// fallback (set in didMove before this is called) still shows through.
    static func build(for mapID: MapID, size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 0
        let theme = theme(for: mapID)
        let tileSize = Balance.tileSize

        guard AssetProvider.loadTileTexture(
            sheetName: theme.sheetName, subdirectory: theme.subdirectory,
            tileSize: tileSize, column: theme.floor.column, row: theme.floor.row
        ) != nil else {
            return container
        }

        let columns = Int(ceil(size.width / CGFloat(tileSize))) + 2
        let rows = Int(ceil(size.height / CGFloat(tileSize))) + 2
        let halfCols = columns / 2
        let halfRows = rows / 2
        let obstacleCells = obstacleCellPositions(columns: columns, rows: rows)

        var obstacleCursor = 0
        for row in 0..<rows {
            for col in 0..<columns {
                let gridX = col - halfCols
                let gridY = row - halfRows
                let isBorder = col == 0 || row == 0 || col == columns - 1 || row == rows - 1

                let tileCoord: TileCoord
                if isBorder {
                    tileCoord = theme.wall
                } else if !theme.obstacles.isEmpty, obstacleCells.contains(GridCell(col: gridX, row: gridY)) {
                    tileCoord = theme.obstacles[obstacleCursor % theme.obstacles.count]
                    obstacleCursor += 1
                } else {
                    tileCoord = theme.floor
                }

                guard let texture = AssetProvider.loadTileTexture(
                    sheetName: theme.sheetName, subdirectory: theme.subdirectory,
                    tileSize: tileSize, column: tileCoord.column, row: tileCoord.row
                ) else { continue }

                let tile = SKSpriteNode(texture: texture)
                tile.size = CGSize(width: tileSize, height: tileSize)
                tile.position = CGPoint(x: CGFloat(gridX) * CGFloat(tileSize), y: CGFloat(gridY) * CGFloat(tileSize))
                container.addChild(tile)
            }
        }
        return container
    }

    /// A handful of fixed fractional positions scattered through the
    /// interior (never on the border ring), so obstacle placement scales
    /// with arena size instead of a hardcoded pixel position that only
    /// looks right at one resolution.
    private static func obstacleCellPositions(columns: Int, rows: Int) -> Set<GridCell> {
        let fractions: [(CGFloat, CGFloat)] = [(-0.35, -0.3), (0.35, 0.25), (0.0, 0.35), (-0.25, 0.15), (0.3, -0.2)]
        return Set(fractions.map { fx, fy in
            GridCell(col: Int((fx * CGFloat(columns)).rounded()), row: Int((fy * CGFloat(rows)).rounded()))
        })
    }
}
