import SpriteKit
import UIKit

/// Every visual kind the game can render. Add new cases here as new entity
/// types are introduced instead of scattering asset lookups elsewhere.
enum EntityVisualKind: String {
    case player
    case walker
    case bullet
}

/// Describes a numbered frame sequence on disk: "skeleton-idle" + count 17
/// means skeleton-idle_0 ... skeleton-idle_16. `subdirectory`, if set, is
/// the path (relative to the bundle root) the frames live under — see the
/// note on resolveImage below for why this matters.
///
/// Kept for backward compatibility (Phase 2's Walker animation loader used
/// this shape). Phase 4's art all ships as single spritesheet files instead
/// — see `SpriteSheetFrames` below — but nothing requires migrating call
/// sites that already work.
struct AnimationFrameSequence {
    let baseName: String
    let count: Int
    let timePerFrame: TimeInterval
    let subdirectory: String?

    init(baseName: String, count: Int, timePerFrame: TimeInterval = 0.08, subdirectory: String? = nil) {
        self.baseName = baseName
        self.count = count
        self.timePerFrame = timePerFrame
        self.subdirectory = subdirectory
    }
}

/// Describes a single spritesheet file: a horizontal strip of `frameCount`
/// equal-size square frames with no padding between them, so frame N is the
/// rect (N * frameSize, 0, frameSize, frameSize). `sheetName` is the bare
/// filename (no extension) resolved the same way as everywhere else in this
/// file — bundle subdirectory path first, then Assets.xcassets.
struct SpriteSheetFrames {
    let sheetName: String
    let frameSize: CGFloat
    let frameCount: Int
    let subdirectory: String?
    let timePerFrame: TimeInterval

    init(sheetName: String, frameSize: CGFloat, frameCount: Int, subdirectory: String? = nil, timePerFrame: TimeInterval = 0.08) {
        self.sheetName = sheetName
        self.frameSize = frameSize
        self.frameCount = frameCount
        self.subdirectory = subdirectory
        self.timePerFrame = timePerFrame
    }
}

/// Centralized, swappable node factory. Falls back to a placeholder colored
/// shape whenever real art can't be found. Two art pipelines are supported:
/// numbered individual frame files (`AnimationFrameSequence`, Phase 2) and
/// single-file horizontal spritesheets (`SpriteSheetFrames`, Phase 4) — both
/// go through the same `resolveImage` bundle lookup, so folder-reference
/// pathing works identically for either.
enum AssetProvider {
    static func makeNode(for kind: EntityVisualKind, radius: CGFloat, fillColor: SKColor) -> SKNode {
        if let image = resolveImage(named: kind.rawValue, subdirectory: "Assets") {
            let sprite = SKSpriteNode(texture: makeTexture(from: image))
            sprite.size = CGSize(width: radius * 2, height: radius * 2)
            return sprite
        }
        return makePlaceholder(radius: radius, fillColor: fillColor)
    }

    /// Loads a numbered frame sequence as textures. Returns nil (rather than
    /// a partial array) if any frame is missing, so callers can cleanly fall
    /// back to a placeholder instead of animating through blank frames.
    static func loadTextures(_ frames: AnimationFrameSequence) -> [SKTexture]? {
        var textures: [SKTexture] = []
        textures.reserveCapacity(frames.count)
        for index in 0..<frames.count {
            let name = "\(frames.baseName)_\(index)"
            guard let image = resolveImage(named: name, subdirectory: frames.subdirectory) else { return nil }
            textures.append(makeTexture(from: image))
        }
        return textures
    }

    /// Builds a sprite running a repeating animation from a numbered frame
    /// sequence. Falls back to the same static placeholder shape used by
    /// makeNode if the frames aren't present yet.
    static func makeAnimatedNode(for kind: EntityVisualKind, frames: AnimationFrameSequence, radius: CGFloat, fillColor: SKColor = .white) -> SKNode {
        guard let textures = loadTextures(frames), let first = textures.first else {
            return makePlaceholder(radius: radius, fillColor: fillColor)
        }
        let sprite = SKSpriteNode(texture: first)
        sprite.size = CGSize(width: radius * 2, height: radius * 2)
        sprite.run(.repeatForever(.animate(with: textures, timePerFrame: frames.timePerFrame)), withKey: "animation")
        return sprite
    }

    /// Slices a horizontal-strip spritesheet (fixed-size square frames, no
    /// padding) into individual textures. Returns nil if the sheet image
    /// itself can't be found, or its pixel dimensions don't fit the
    /// requested frame size/count (a sign the frame size/count is wrong for
    /// this file) — same "fail whole, not partial" contract as loadTextures.
    static func loadSpriteSheetTextures(_ sheet: SpriteSheetFrames) -> [SKTexture]? {
        guard let image = resolveImage(named: sheet.sheetName, subdirectory: sheet.subdirectory),
              let cgImage = image.cgImage else { return nil }

        let frameSize = Int(sheet.frameSize)
        guard frameSize > 0,
              cgImage.width >= frameSize * sheet.frameCount,
              cgImage.height >= frameSize
        else { return nil }

        var textures: [SKTexture] = []
        textures.reserveCapacity(sheet.frameCount)
        for index in 0..<sheet.frameCount {
            let rect = CGRect(x: index * frameSize, y: 0, width: frameSize, height: frameSize)
            guard let cropped = cgImage.cropping(to: rect) else { return nil }
            let texture = SKTexture(cgImage: cropped)
            texture.filteringMode = .nearest
            textures.append(texture)
        }
        return textures
    }

    /// Sheet-based sibling of makeAnimatedNode: builds a sprite running a
    /// repeating animation sliced from a single spritesheet file. Falls back
    /// to a placeholder shape if the sheet can't be loaded/sliced.
    static func makeAnimatedNode(sheet: SpriteSheetFrames, size: CGSize, fallbackColor: SKColor = .white) -> SKNode {
        guard let textures = loadSpriteSheetTextures(sheet), let first = textures.first else {
            return makePlaceholder(radius: max(size.width, size.height) / 2, fillColor: fallbackColor)
        }
        let sprite = SKSpriteNode(texture: first)
        sprite.size = size
        sprite.run(.repeatForever(.animate(with: textures, timePerFrame: sheet.timePerFrame)), withKey: "animation")
        return sprite
    }

    /// Extracts one square tile from a grid-based tilesheet (addressed by
    /// column/row, unlike the single-row spritesheet slicer above) — used by
    /// TileMapBuilder. Top-left origin: column/row 0,0 is the tile in the
    /// sheet's top-left corner, matching how the sheet reads visually.
    static func loadTileTexture(sheetName: String, subdirectory: String?, tileSize: Int, column: Int, row: Int) -> SKTexture? {
        guard let image = resolveImage(named: sheetName, subdirectory: subdirectory),
              let cgImage = image.cgImage else { return nil }

        let rect = CGRect(x: column * tileSize, y: row * tileSize, width: tileSize, height: tileSize)
        guard rect.maxX <= CGFloat(cgImage.width), rect.maxY <= CGFloat(cgImage.height),
              let cropped = cgImage.cropping(to: rect)
        else { return nil }

        let texture = SKTexture(cgImage: cropped)
        texture.filteringMode = .nearest
        return texture
    }

    /// Loads sheetName as a 9-slice-stretchable panel sprite via
    /// SKSpriteNode.centerRect, so pixel-art corners/edges stay crisp while
    /// only the middle stretches to fit `size` — used for panel1/panel2 UI
    /// backgrounds. Returns nil (not a placeholder) if the sheet can't be
    /// found; callers already have a background of their own (a flat scene
    /// color or a plain shape) to fall back to.
    static func makeResizablePanel(sheetName: String, subdirectory: String, size: CGSize, centerRect: CGRect = CGRect(x: 1.0 / 3, y: 1.0 / 3, width: 1.0 / 3, height: 1.0 / 3)) -> SKSpriteNode? {
        guard let image = resolveImage(named: sheetName, subdirectory: subdirectory) else { return nil }
        let sprite = SKSpriteNode(texture: makeTexture(from: image), size: size)
        sprite.centerRect = centerRect
        return sprite
    }

    /// `UIImage(named:)` only checks the bundle root and compiled asset
    /// catalogs (Assets.xcassets) — it does NOT recursively search
    /// subdirectories. Xcode "folder references" (like our Assets/ folder)
    /// preserve their on-disk directory structure inside the app bundle
    /// instead of flattening it, so a file at
    /// ZombieSurvival/Assets/Characters/Zombie1/idle.png ends up at
    /// <bundle>/Assets/Characters/Zombie1/idle.png — invisible to a bare
    /// `UIImage(named: "idle")` lookup. We look it up by explicit bundle
    /// path first and only fall back to the bare `named:` lookup, which
    /// covers Assets.xcassets entries (those have no filesystem path/
    /// subdirectory concept, so the explicit-path lookup can't apply there).
    private static func resolveImage(named name: String, subdirectory: String?) -> UIImage? {
        if let subdirectory,
           let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: name)
    }

    /// Pixel art blurs when SpriteKit's default linear filtering scales it —
    /// every texture handed out by this file uses nearest-neighbor instead.
    private static func makeTexture(from image: UIImage) -> SKTexture {
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func makePlaceholder(radius: CGFloat, fillColor: SKColor) -> SKShapeNode {
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = fillColor
        shape.strokeColor = .white
        shape.lineWidth = 2
        return shape
    }
}
