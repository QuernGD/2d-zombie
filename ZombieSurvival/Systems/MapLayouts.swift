import CoreGraphics

/// What a single parsed layout cell is. `spawn` is a floor cell that also
/// marks a zombie spawn point, so it's walkable like any other floor.
enum MapCell {
    case floor
    case wall
    case obstacle
    case spawn

    var isWalkable: Bool {
        switch self {
        case .floor, .spawn: return true
        case .wall, .obstacle: return false
        }
    }

    /// Walls and obstacles both block movement, but they're drawn from
    /// different tile art (structural wall vs. scattered cover prop).
    var isSolid: Bool { !isWalkable }
}

/// A layout after parsing: a rectangular grid of cells plus the spawn
/// cells pulled out for WaveManager. Row 0 is the TOP row as the ASCII
/// literal reads on screen.
struct ParsedMapLayout {
    let columns: Int
    let rows: Int
    /// Row-major, exactly `rows * columns` entries.
    let cells: [MapCell]
    let spawnCells: [TileCoord]

    func cell(column: Int, row: Int) -> MapCell {
        guard column >= 0, column < columns, row >= 0, row < rows else { return .wall }
        return cells[row * columns + column]
    }
}

/// Hand-editable ASCII arena layouts, one per map.
///
///     '#' wall (solid, structural — the arena boundary)
///     '.' floor (walkable)
///     'X' obstacle (solid cover the player can circle around)
///     'S' spawn point (walkable floor, used by WaveManager)
///
/// Both layouts below were checked against the design rules this system is
/// built around before being committed, and `TileMapBuilder` re-verifies
/// the important ones (full connectivity, spawn validity) at build time:
///
///  - Fully connected: every walkable cell reaches every other walkable
///    cell, so no zombie can ever be routed into an unreachable pocket.
///  - No dead ends: no walkable cell has fewer than two walkable
///    neighbours, so there's nowhere the player can back into and be safe.
///  - Cover, not walls: obstacles are 1-2 tile clusters with at least 3
///    free tiles between them and from the border, so everything can be
///    circled rather than hidden behind.
///  - Spawns sit on the perimeter, spread along all four edges, so no
///    single corner can be camped.
enum MapLayouts {
    /// Open outdoor arena. Cover is scattered wreckage and vehicles in two
    /// staggered bands, leaving wide lanes in every direction.
    ///
    /// Spawn markers sit two cells in from the border, never against it: a
    /// zombie's collision circle is wider than one tile, so a marker hard
    /// against a wall would be relocated by the spawn validator on every
    /// single round.
    static let wasteland: [String] = [
        "###################################",
        "#.................................#",
        "#....S.......S.......S.......S....#",
        "#.................................#",
        "#....XX....XX....XX....XX....XX...#",
        "#....XX..........XX..........XX...#",
        "#.................................#",
        "#.S.............................S.#",
        "#.................................#",
        "#.......XX....XX....XX....XX......#",
        "#.......XX..........XX............#",
        "#.................................#",
        "#....S.......S.......S.......S....#",
        "#.................................#",
        "###################################"
    ]

    /// Indoor facility. Two pass-through rooms — each with a doorway in
    /// the top *and* bottom wall, so neither is a single-entrance trap —
    /// sit inside a ring of corridors at least 3 tiles wide, giving
    /// several routes between any two points.
    ///
    /// Doorways are 3 tiles wide on purpose. A 1-tile gap is narrower than
    /// a player/zombie collision circle, which would seal the rooms off
    /// entirely while the tile grid still happily routed enemies into them.
    static let interior: [String] = [
        "###################################",
        "#.................................#",
        "#....S.......S.......S.......S....#",
        "#.................................#",
        "#.................................#",
        "#.......##...##.....##...##.......#",
        "#...X...#.....#.....#.....#...X...#",
        "#.S.X...#.....#.....#.....#...X.S.#",
        "#...X...#.....#.....#.....#...X...#",
        "#.......##...##.....##...##.......#",
        "#.................................#",
        "#.................................#",
        "#....S.......S.......S.......S....#",
        "#.................................#",
        "###################################"
    ]

    static func rows(for mapID: MapID) -> [String] {
        switch mapID {
        case .original: return wasteland
        case .facility: return interior
        }
    }

    /// Parses an ASCII layout. Rows shorter than the widest row are padded
    /// with walls rather than silently producing a ragged grid — a
    /// mistyped literal then shows up as an obviously wrong wall instead of
    /// an out-of-bounds crash.
    static func parse(_ rows: [String]) -> ParsedMapLayout {
        let columns = rows.map(\.count).max() ?? 0
        assert(rows.allSatisfy { $0.count == columns }, "Ragged map layout: every row must be the same width")

        var cells: [MapCell] = []
        cells.reserveCapacity(columns * rows.count)
        var spawnCells: [TileCoord] = []

        for (rowIndex, row) in rows.enumerated() {
            var characters = Array(row)
            if characters.count < columns {
                characters.append(contentsOf: Array(repeating: "#", count: columns - characters.count))
            }
            for (columnIndex, character) in characters.enumerated() {
                switch character {
                case "#": cells.append(.wall)
                case "X": cells.append(.obstacle)
                case "S":
                    cells.append(.spawn)
                    spawnCells.append(TileCoord(column: columnIndex, row: rowIndex))
                default: cells.append(.floor)
                }
            }
        }

        return ParsedMapLayout(columns: columns, rows: rows.count, cells: cells, spawnCells: spawnCells)
    }
}
