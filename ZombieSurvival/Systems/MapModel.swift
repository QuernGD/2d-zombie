import CoreGraphics
import SpriteKit

/// The map as the first-person build needs it: the same ASCII layout from
/// MapLayouts (unchanged), turned into world-space geometry, a NavGrid for
/// enemy pathfinding (also unchanged), and the wall/obstacle tile art each
/// cell should be textured with.
///
/// Coordinate conventions, which everything downstream depends on:
///  - **World space**: x right, y *up*, one cell is `RaycasterConfig.cellSize`.
///    This matches what NavGrid already expects (it maps a growing row
///    index to a decreasing y), so NavGrid carries over untouched.
///  - **Grid space**: (gridX, gridY) = (worldX / cell, -worldY / cell), so
///    cell (column, row) occupies gridX ∈ [column, column+1] and
///    gridY ∈ [row, row+1]. The raycaster works entirely in grid space
///    because DDA is trivial when a cell is exactly 1 unit.
final class MapModel {
    let mapID: MapID
    let layout: ParsedMapLayout
    let cellSize: CGFloat
    let navGrid: NavGrid
    let solidRects: [CGRect]
    let spawnPoints: [CGPoint]
    let playerStart: CGPoint

    let sheetName: String
    let sheetSubdirectory: String

    private let wallTile: TileCoord
    private let propTiles: [TileCoord]

    init(mapID: MapID) {
        self.mapID = mapID
        self.layout = MapLayouts.parse(MapLayouts.rows(for: mapID))
        let cell = RaycasterConfig.cellSize
        self.cellSize = cell

        switch mapID {
        case .original:
            sheetName = "wasteland"
            wallTile = Balance.wastelandWallTile
            propTiles = Balance.wastelandPropTiles
        case .facility:
            sheetName = "interior"
            wallTile = Balance.interiorWallTile
            propTiles = Balance.interiorPropTiles
        }
        sheetSubdirectory = "Assets/Tiles"

        // Top-left cell centre at (cell/2, -cell/2) puts the map's top edge
        // on y = 0 and its left edge on x = 0, which makes the grid-space
        // conversion above a plain divide with no offset term.
        let topLeftCenter = CGPoint(x: cell / 2, y: -cell / 2)
        self.navGrid = NavGrid(layout: layout, tileSize: cell, topLeftCenter: topLeftCenter)

        var rects: [CGRect] = []
        for row in 0..<layout.rows {
            for column in 0..<layout.columns where layout.cell(column: column, row: row).isSolid {
                let centre = CGPoint(x: CGFloat(column) * cell + cell / 2, y: -(CGFloat(row) * cell + cell / 2))
                rects.append(CGRect(x: centre.x - cell / 2, y: centre.y - cell / 2, width: cell, height: cell))
            }
        }
        self.solidRects = rects

        self.spawnPoints = layout.spawnCells.map {
            CGPoint(x: CGFloat($0.column) * cell + cell / 2, y: -(CGFloat($0.row) * cell + cell / 2))
        }

        // Start on the walkable cell nearest the middle of the map. Both
        // shipped layouts have open floor dead centre, but searching keeps
        // a hand-edited layout from spawning the player inside a wall.
        let midColumn = layout.columns / 2
        let midRow = layout.rows / 2
        var best: (distance: Int, point: CGPoint)?
        for row in 0..<layout.rows {
            for column in 0..<layout.columns where layout.cell(column: column, row: row).isWalkable {
                let distance = abs(column - midColumn) + abs(row - midRow)
                if best == nil || distance < best!.distance {
                    best = (distance, CGPoint(x: CGFloat(column) * cell + cell / 2, y: -(CGFloat(row) * cell + cell / 2)))
                }
            }
        }
        self.playerStart = best?.point ?? .zero

        // Build-time layout validation, carried over from the top-down
        // build (it used to live in TileMapBuilder). A sealed-off pocket
        // means enemies can never path there, so it fails loudly rather
        // than shipping as a mystery.
        if !navGrid.isFullyConnected() {
            let message = "Map \(mapID.rawValue): walkable space is NOT fully connected — some area is sealed off and enemies can never path there. Fix the layout in MapLayouts.swift."
            print("⚠️ \(message)")
            assertionFailure(message)
        }
    }

    // MARK: - Coordinate conversion

    func gridPosition(ofWorld point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / cellSize, y: -point.y / cellSize)
    }

    func worldPosition(ofGrid point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * cellSize, y: -point.y * cellSize)
    }

    // MARK: - Grid queries

    /// Out-of-bounds counts as solid so a ray that escapes the map (only
    /// possible if a layout's border ring were broken) terminates instead
    /// of marching to the depth limit.
    func isSolid(column: Int, row: Int) -> Bool {
        guard column >= 0, column < layout.columns, row >= 0, row < layout.rows else { return true }
        return layout.cell(column: column, row: row).isSolid
    }

    func isSolid(atWorld point: CGPoint) -> Bool {
        let grid = gridPosition(ofWorld: point)
        return isSolid(column: Int(floor(grid.x)), row: Int(floor(grid.y)))
    }

    /// Which tile art a solid cell is textured with. Obstacles cycle
    /// deterministically through the theme's prop tiles so a wall of crates
    /// isn't all one image, but the same cell always picks the same tile.
    func wallTexture(column: Int, row: Int) -> TileCoord {
        guard column >= 0, column < layout.columns, row >= 0, row < layout.rows else { return wallTile }
        switch layout.cell(column: column, row: row) {
        case .obstacle where !propTiles.isEmpty:
            let hash = abs(column &* 73856093 ^ row &* 19349663)
            return propTiles[hash % propTiles.count]
        default:
            return wallTile
        }
    }

    /// Every distinct tile the renderer can be asked to draw, so the strip
    /// cache can be built once up front instead of lazily mid-frame.
    var usedWallTiles: [TileCoord] {
        var tiles: Set<TileCoord> = [wallTile]
        for tile in propTiles { tiles.insert(tile) }
        return Array(tiles)
    }
}
