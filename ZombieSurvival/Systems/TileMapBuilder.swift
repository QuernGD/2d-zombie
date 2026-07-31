import SpriteKit

/// Builds a tile-based arena background from one of the two 32x32 tilesets,
/// replacing Phase 1-3's plain bordered rectangle. Neither tileset ships
/// with a documented tile-index legend, so the column/row picks in Balance
/// (wastelandFloorTile, interiorWallTile, etc.) are a best-effort visual
/// guess — treat them as a starting point to eyeball and adjust in Xcode,
/// not as verified ground truth.
///
/// As of Phase 7, each map is composed of three layers instead of one flat
/// floor + scattered single tiles:
///  1. Floor (randomized among a few plain variants, so it isn't one
///     repeated tile) with a wall ring around the border.
///  2. Small single-tile scatter clutter (barrels, crates, drawers).
///  3. Named multi-tile "structures" (cars, crate stacks, vending
///     machines, furniture clusters) — real recognizable objects instead
///     of another lone repeated obstacle tile.
///
/// Wall and every occupied scatter/structure tile are solid: `build` also
/// returns their world-space rects so GameScene can block player/enemy
/// movement through them (see Geometry.swift's resolveCollision). Floor
/// tiles are never solid.
enum TileMapBuilder {
    struct Result {
        let node: SKNode
        let solidRects: [CGRect]
    }

    private struct Theme {
        let sheetName: String
        let subdirectory: String
        let floor: TileCoord
        let floorVariants: [TileCoord]
        let wall: TileCoord
        let scatterTiles: [TileCoord]
        let scatterLayout: [(CGFloat, CGFloat)]
        let structurePlacements: [((CGFloat, CGFloat), MapStructure)]
    }

    private static func theme(for mapID: MapID) -> Theme {
        switch mapID {
        case .original:
            // "The Yard" -> the outdoor Wasteland tileset.
            return Theme(
                sheetName: "wasteland",
                subdirectory: "Assets/Tiles",
                floor: Balance.wastelandFloorTile,
                floorVariants: Balance.wastelandFloorVariants,
                wall: Balance.wastelandWallTile,
                scatterTiles: Balance.wastelandObstacleTiles,
                scatterLayout: Balance.wastelandObstacleLayout,
                structurePlacements: Balance.wastelandStructurePlacements
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
                floorVariants: Balance.interiorFloorVariants,
                wall: Balance.interiorWallTile,
                scatterTiles: Balance.interiorObstacleTiles,
                scatterLayout: Balance.interiorObstacleLayout,
                structurePlacements: Balance.interiorStructurePlacements
            )
        }
    }

    private struct GridCell: Hashable { let col: Int; let row: Int }

    /// Returns a node ready to add to the world layer (tiling `size`,
    /// centered at 0,0 like everything else in GameScene's worldLayer) plus
    /// the world-space rects of every solid (wall/scatter/structure) tile
    /// placed. Both are empty if the theme's floor tile can't be loaded at
    /// all, so GameScene's plain background-color fallback (set in didMove
    /// before this is called) still shows through with no phantom collision.
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
        let scatterCells = fractionalCells(theme.scatterLayout, columns: columns, rows: rows)

        // Structures are stamped in a second pass (below) so they can
        // overwrite/skip the base floor pass cleanly; precompute which
        // grid cells they'll occupy so the base pass never draws a floor
        // tile underneath one for nothing.
        var structureOccupiedCells: Set<GridCell> = []
        for (anchor, structure) in theme.structurePlacements {
            let base = fractionalCell(anchor, columns: columns, rows: rows)
            for dRow in 0..<structure.height {
                for dCol in 0..<structure.width {
                    structureOccupiedCells.insert(GridCell(col: base.col + dCol, row: base.row + dRow))
                }
            }
        }

        var solidRects: [CGRect] = []
        var scatterCursor = 0

        for row in 0..<rows {
            for col in 0..<columns {
                let gridX = col - halfCols
                let gridY = row - halfRows
                let cell = GridCell(col: gridX, row: gridY)
                guard !structureOccupiedCells.contains(cell) else { continue }

                let isBorder = col == 0 || row == 0 || col == columns - 1 || row == rows - 1
                let isScatter = !theme.scatterTiles.isEmpty && scatterCells.contains(cell)

                let tileCoord: TileCoord
                if isBorder {
                    tileCoord = theme.wall
                } else if isScatter {
                    tileCoord = theme.scatterTiles[scatterCursor % theme.scatterTiles.count]
                    scatterCursor += 1
                } else {
                    tileCoord = theme.floorVariants.isEmpty ? theme.floor : theme.floorVariants.randomElement() ?? theme.floor
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

                if isBorder || isScatter {
                    solidRects.append(solidRect(at: tilePosition, tileSize: tileSize))
                }
            }
        }

        // Structures: stamped on top, each a contiguous width x height
        // rectangle read straight out of the sheet starting at its origin.
        for (anchor, structure) in theme.structurePlacements {
            let base = fractionalCell(anchor, columns: columns, rows: rows)
            for dRow in 0..<structure.height {
                for dCol in 0..<structure.width {
                    guard let texture = AssetProvider.loadTileTexture(
                        sheetName: theme.sheetName, subdirectory: theme.subdirectory, tileSize: tileSize,
                        column: structure.origin.column + dCol, row: structure.origin.row + dRow
                    ) else { continue }

                    let gridX = base.col + dCol
                    let gridY = base.row + dRow
                    let tilePosition = CGPoint(x: CGFloat(gridX) * CGFloat(tileSize), y: CGFloat(gridY) * CGFloat(tileSize))
                    let tile = SKSpriteNode(texture: texture)
                    tile.size = CGSize(width: tileSize, height: tileSize)
                    tile.position = tilePosition
                    tile.zPosition = 1
                    container.addChild(tile)
                    solidRects.append(solidRect(at: tilePosition, tileSize: tileSize))
                }
            }
        }

        return Result(node: container, solidRects: solidRects)
    }

    private static func solidRect(at position: CGPoint, tileSize: Int) -> CGRect {
        CGRect(
            x: position.x - CGFloat(tileSize) / 2, y: position.y - CGFloat(tileSize) / 2,
            width: CGFloat(tileSize), height: CGFloat(tileSize)
        )
    }

    /// Converts one fractional (x, y) position into a concrete grid cell,
    /// scaling with arena size instead of a hardcoded pixel position that
    /// only looks right at one resolution.
    private static func fractionalCell(_ fraction: (CGFloat, CGFloat), columns: Int, rows: Int) -> GridCell {
        GridCell(col: Int((fraction.0 * CGFloat(columns)).rounded()), row: Int((fraction.1 * CGFloat(rows)).rounded()))
    }

    private static func fractionalCells(_ fractions: [(CGFloat, CGFloat)], columns: Int, rows: Int) -> Set<GridCell> {
        Set(fractions.map { fractionalCell($0, columns: columns, rows: rows) })
    }
}
