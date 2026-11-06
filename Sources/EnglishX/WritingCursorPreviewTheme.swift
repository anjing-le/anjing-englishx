import AppKit

/// A local-preview-only cursor trial. Assets and their original notice live
/// outside version control; a missing/invalid pair falls back as one family.
@MainActor
struct WritingCursorPreviewTheme {
    let arrow: NSCursor
    let pointer: NSCursor

    private struct Manifest: Decodable {
        struct Artwork: Decodable { let file: String; let hotspot: [Double] }
        let logicalSize: Double
        let arrow: Artwork
        let pointer: Artwork
    }

    static func load(from directory: URL) -> Self? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("cursors.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.logicalSize.isFinite, (12...48).contains(manifest.logicalSize) else { return nil }
        func load(_ artwork: Manifest.Artwork) -> NSCursor? {
            guard artwork.file == (artwork.file as NSString).lastPathComponent,
                  artwork.file.hasSuffix(".png"), artwork.hotspot.count == 2,
                  artwork.hotspot.allSatisfy({ $0.isFinite && $0 >= 0 }),
                  let image = NSImage(contentsOf: directory.appendingPathComponent(artwork.file)),
                  let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
                  bitmap.pixelsWide > 0, bitmap.pixelsWide == bitmap.pixelsHigh,
                  artwork.hotspot.allSatisfy({ $0 < Double(bitmap.pixelsWide) }) else { return nil }
            let ratio = manifest.logicalSize / Double(bitmap.pixelsWide)
            image.size = NSSize(width: manifest.logicalSize, height: manifest.logicalSize)
            return NSCursor(image: image, hotSpot: NSPoint(x: artwork.hotspot[0] * ratio, y: artwork.hotspot[1] * ratio))
        }
        guard let arrow = load(manifest.arrow), let pointer = load(manifest.pointer) else { return nil }
        return Self(arrow: arrow, pointer: pointer)
    }

    func cursor(for role: WritingCursorRole) -> NSCursor {
        switch role {
        case .standard, .disabled: return arrow
        case .clickable, .drag, .dragging: return pointer
        case .text: return .iBeam
        case .splitResize: return .resizeUpDown
        case .columnResize: return .resizeLeftRight
        }
    }
}
