import CoreGraphics
import Foundation

/// Walkability grid + shared flow field for enemy navigation.
///
/// Rather than running A* per zombie (25 concurrent searches every time
/// anything moves), this runs a single breadth-first search *outward from
/// the player's cell* across all walkable cells, recording for each cell
/// which neighbour steps toward the player. Every zombie then just reads
/// one vector out of that array — one BFS serves the whole horde, and the
/// cost is independent of enemy count.
///
/// The BFS is only re-run when the player crosses into a different tile
/// (see `updateFlowField`), so standing still or jittering inside one tile
/// costs nothing.
final class NavGrid {
    let columns: Int
    let rows: Int
    let tileSize: CGFloat
    /// World position of the centre of cell (column: 0, row: 0) — i.e. the
    /// top-left cell. Row index grows downward, world y grows upward.
    private let topLeftCenter: CGPoint

    private let walkable: [Bool]
    /// Unit vector from each cell toward the next cell on the way to the
    /// player. `.zero` where no route exists (or at the player's own cell).
    private var flow: [CGVector]
    /// Index of the cell the last flow field was built from, so a player
    /// staying inside one tile never triggers a rebuild.
    private var lastSourceIndex: Int = -1
    /// Diagnostics only — how many BFS passes have run this scene.
    private(set) var rebuildCount: Int = 0

    /// 8-connected so zombies can move diagonally instead of stair-stepping.
    private static let neighborOffsets: [(dc: Int, dr: Int)] = [
        (0, -1), (0, 1), (-1, 0), (1, 0),
        (-1, -1), (1, -1), (-1, 1), (1, 1)
    ]

    init(layout: ParsedMapLayout, tileSize: CGFloat, topLeftCenter: CGPoint) {
        self.columns = layout.columns
        self.rows = layout.rows
        self.tileSize = tileSize
        self.topLeftCenter = topLeftCenter
        self.walkable = layout.cells.map(\.isWalkable)
        self.flow = Array(repeating: .zero, count: layout.columns * layout.rows)
    }

    // MARK: - Coordinate conversion

    func worldPosition(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: topLeftCenter.x + CGFloat(column) * tileSize,
            y: topLeftCenter.y - CGFloat(row) * tileSize
        )
    }

    private func index(column: Int, row: Int) -> Int? {
        guard column >= 0, column < columns, row >= 0, row < rows else { return nil }
        return row * columns + column
    }

    private func index(for worldPoint: CGPoint) -> Int? {
        let column = Int(((worldPoint.x - topLeftCenter.x) / tileSize).rounded())
        let row = Int(((topLeftCenter.y - worldPoint.y) / tileSize).rounded())
        return index(column: column, row: row)
    }

    func isWalkable(worldPoint: CGPoint) -> Bool {
        guard let index = index(for: worldPoint) else { return false }
        return walkable[index]
    }

    var walkableCellCount: Int { walkable.lazy.filter { $0 }.count }

    // MARK: - Connectivity

    /// Flood-fills the walkable space and reports whether every walkable
    /// cell was reached. A false result means some part of the map is
    /// sealed off — zombies could never path there, so MapModel logs it
    /// loudly at map load rather than letting it ship silently.
    func isFullyConnected() -> Bool {
        guard let start = walkable.firstIndex(of: true) else { return true }
        var visited = [Bool](repeating: false, count: walkable.count)
        var queue = [start]
        queue.reserveCapacity(walkable.count)
        visited[start] = true
        var reached = 1
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1
            forEachWalkableNeighbor(of: current) { neighbor in
                guard !visited[neighbor] else { return }
                visited[neighbor] = true
                reached += 1
                queue.append(neighbor)
            }
        }
        return reached == walkableCellCount
    }

    // MARK: - Flow field

    /// Rebuilds the flow field only if the player has moved into a
    /// different cell since the last rebuild. Safe (and cheap) to call
    /// every frame.
    func updateFlowField(playerPosition: CGPoint) {
        guard let source = nearestWalkableIndex(to: playerPosition), source != lastSourceIndex else { return }
        lastSourceIndex = source
        rebuildFlowField(from: source)
    }

    /// The direction a zombie standing at `worldPoint` should move to get
    /// closer to the player. Nil if the point is off-grid or no route
    /// exists — callers fall back to straight-line pursuit.
    func flowDirection(at worldPoint: CGPoint) -> CGVector? {
        guard let index = index(for: worldPoint) else { return nil }
        let direction = flow[index]
        return direction.isZero ? nil : direction
    }

    private func rebuildFlowField(from source: Int) {
        rebuildCount += 1
        for i in flow.indices { flow[i] = .zero }

        var visited = [Bool](repeating: false, count: walkable.count)
        var queue = [source]
        queue.reserveCapacity(walkable.count)
        visited[source] = true
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1
            let currentColumn = current % columns
            let currentRow = current / columns

            for offset in Self.neighborOffsets {
                let neighborColumn = currentColumn + offset.dc
                let neighborRow = currentRow + offset.dr
                guard let neighbor = index(column: neighborColumn, row: neighborRow),
                      !visited[neighbor], walkable[neighbor] else { continue }
                // Don't let a diagonal step squeeze through the corner
                // between two solid tiles — it looks like clipping through
                // a wall and fights the collision resolver.
                if offset.dc != 0, offset.dr != 0 {
                    guard let sideA = index(column: neighborColumn, row: currentRow),
                          let sideB = index(column: currentColumn, row: neighborRow),
                          walkable[sideA], walkable[sideB] else { continue }
                }

                visited[neighbor] = true
                // BFS expands away from the player, so the cell we came
                // from is always one step closer — point back at it.
                // Grid rows grow downward while world y grows upward,
                // hence the sign flip on dy.
                flow[neighbor] = CGVector(dx: CGFloat(-offset.dc), dy: CGFloat(offset.dr)).normalized
                queue.append(neighbor)
            }
        }
    }

    /// The player should always be standing on a walkable cell, but a
    /// rounding edge case (or being nudged into a wall by collision
    /// resolution) shouldn't kill navigation for the whole horde — search
    /// outward for the closest walkable cell instead.
    private func nearestWalkableIndex(to worldPoint: CGPoint) -> Int? {
        let column = Int(((worldPoint.x - topLeftCenter.x) / tileSize).rounded())
        let row = Int(((topLeftCenter.y - worldPoint.y) / tileSize).rounded())
        if let index = index(column: column, row: row), walkable[index] { return index }

        let maxRadius = max(columns, rows)
        guard maxRadius > 0 else { return nil }
        for radius in 1...maxRadius {
            for dr in -radius...radius {
                for dc in -radius...radius where abs(dr) == radius || abs(dc) == radius {
                    if let index = index(column: column + dc, row: row + dr), walkable[index] {
                        return index
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Line of sight

    /// Samples along the segment to see whether it crosses any solid cell.
    /// Used so a zombie with a clear shot at the player walks straight at
    /// them (which looks far better than following grid-aligned flow
    /// vectors) and only falls back to the flow field when actually
    /// blocked.
    func hasLineOfSight(from start: CGPoint, to end: CGPoint) -> Bool {
        let delta = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let distance = delta.length
        guard distance > 0 else { return true }

        let step = max(tileSize * Balance.navLineOfSightSampleFraction, 1)
        let sampleCount = Int(distance / step)
        guard sampleCount > 0 else { return true }

        for sample in 1...sampleCount {
            let t = CGFloat(sample) / CGFloat(sampleCount)
            let point = CGPoint(x: start.x + delta.dx * t, y: start.y + delta.dy * t)
            if !isWalkable(worldPoint: point) { return false }
        }
        return true
    }

    // MARK: - Helpers

    private func forEachWalkableNeighbor(of index: Int, _ body: (Int) -> Void) {
        let column = index % columns
        let row = index / columns
        for offset in Self.neighborOffsets {
            guard let neighbor = self.index(column: column + offset.dc, row: row + offset.dr),
                  walkable[neighbor] else { continue }
            if offset.dc != 0, offset.dr != 0 {
                guard let sideA = self.index(column: column + offset.dc, row: row),
                      let sideB = self.index(column: column, row: row + offset.dr),
                      walkable[sideA], walkable[sideB] else { continue }
            }
            body(neighbor)
        }
    }
}
