import SpriteKit

/// Pre-slices each wall tile into its vertical 1-pixel strips, once, at
/// map load.
///
/// This is the difference between a raycaster that runs and one that
/// doesn't: the renderer needs an arbitrary vertical strip of a wall
/// texture for every column of the screen, every frame. Cropping those out
/// per frame (240 crops × 60fps) would be hopeless. `SKTexture(rect:in:)`
/// instead returns a lightweight *reference* into the parent texture's
/// atlas entry — no pixel copying — so all 32 strips of a tile can be made
/// once and then just assigned to sprite nodes forever after.
final class WallTextureCache {
    private var stripsByTile: [TileCoord: [SKTexture]] = [:]
    private let sheetName: String
    private let subdirectory: String
    private let sourceTileSize: Int

    /// Number of strips per tile — one per source pixel column, so texture
    /// X resolution exactly matches the art.
    var stripCount: Int { sourceTileSize }

    init(sheetName: String, subdirectory: String, sourceTileSize: Int = Balance.tileSize) {
        self.sheetName = sheetName
        self.subdirectory = subdirectory
        self.sourceTileSize = sourceTileSize
    }

    /// Builds strips for every tile the map can ask for. Called once at
    /// scene setup so nothing has to be generated mid-frame.
    func preload(tiles: [TileCoord]) {
        for tile in tiles {
            _ = strips(for: tile)
        }
    }

    func strips(for tile: TileCoord) -> [SKTexture]? {
        if let cached = stripsByTile[tile] { return cached }
        guard let source = AssetProvider.loadTileTexture(
            sheetName: sheetName, subdirectory: subdirectory,
            tileSize: sourceTileSize, column: tile.column, row: tile.row
        ) else { return nil }

        let count = sourceTileSize
        let width = 1.0 / CGFloat(count)
        var strips: [SKTexture] = []
        strips.reserveCapacity(count)
        for index in 0..<count {
            // SKTexture rects are normalised with a bottom-left origin;
            // strip index still runs left-to-right, which is what texX means.
            let rect = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: 1)
            let strip = SKTexture(rect: rect, in: source)
            strip.filteringMode = .nearest
            strips.append(strip)
        }
        stripsByTile[tile] = strips
        return strips
    }
}
