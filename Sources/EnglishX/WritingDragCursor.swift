import AppKit

/// Small, deterministic additions to the Richfree white-glove cursor family.
/// Draw at 2x once; both poses share canvas, wrist and palm hotspot.
@MainActor
enum WritingDragCursor {
    static let open = make(closed: false)
    static let closed = make(closed: true)

    private static func make(closed: Bool) -> NSCursor {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: 40, height: 40))
        context.cgContext.scaleBy(x: 2, y: 2)
        context.cgContext.translateBy(x: 0, y: 20)
        context.cgContext.scaleBy(x: 1, y: -1)
        context.cgContext.translateBy(x: 9.5, y: 10)
        context.cgContext.rotate(by: -.pi / 12)
        context.cgContext.translateBy(x: -9.5, y: -10)
        context.shouldAntialias = true

        let hand = closed ? closedOutline() : openOutline()
        hand.lineJoinStyle = .round; hand.lineCapStyle = .round
        hand.lineWidth = 1.1
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        NSColor(calibratedWhite: 0.18, alpha: 1).setStroke()
        hand.fill(); hand.stroke()

        let folds = NSBezierPath()
        folds.lineWidth = 0.55; folds.lineCapStyle = .round
        folds.move(to: NSPoint(x: 8.4, y: 16.1))
        folds.curve(to: NSPoint(x: 13.8, y: 14.3), controlPoint1: NSPoint(x: 10, y: 16), controlPoint2: NSPoint(x: 12.4, y: 15))
        if closed {
            folds.move(to: NSPoint(x: 5.9, y: 10.2))
            folds.curve(to: NSPoint(x: 11.9, y: 11.4), controlPoint1: NSPoint(x: 8.1, y: 8.7), controlPoint2: NSPoint(x: 11.8, y: 9.8))
            folds.move(to: NSPoint(x: 7.2, y: 6.2)); folds.line(to: NSPoint(x: 7.8, y: 8))
            folds.move(to: NSPoint(x: 9.9, y: 5.8)); folds.line(to: NSPoint(x: 10.2, y: 7.9))
            folds.move(to: NSPoint(x: 12.6, y: 6.3)); folds.line(to: NSPoint(x: 12.8, y: 8.2))
        }
        NSColor(calibratedWhite: 0.52, alpha: 0.8).setStroke(); folds.stroke()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.addRepresentation(bitmap)
        return NSCursor(image: image, hotSpot: NSPoint(x: 9.5, y: 10))
    }

    private static func openOutline() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 8.6, y: 18))
        p.line(to: NSPoint(x: 6.1, y: 15.4))
        p.curve(to: NSPoint(x: 3.4, y: 12.5), controlPoint1: NSPoint(x: 5.5, y: 14.7), controlPoint2: NSPoint(x: 4.5, y: 13.7))
        p.line(to: NSPoint(x: 1.9, y: 10.7))
        p.curve(to: NSPoint(x: 3.3, y: 9), controlPoint1: NSPoint(x: 1.1, y: 9.6), controlPoint2: NSPoint(x: 2.2, y: 8.4))
        p.line(to: NSPoint(x: 5.6, y: 10.6)); p.line(to: NSPoint(x: 3.5, y: 5.6))
        p.curve(to: NSPoint(x: 5.5, y: 4.9), controlPoint1: NSPoint(x: 2.9, y: 4.1), controlPoint2: NSPoint(x: 4.8, y: 3.5))
        p.line(to: NSPoint(x: 7, y: 8)); p.line(to: NSPoint(x: 5.9, y: 2.9))
        p.curve(to: NSPoint(x: 8, y: 2.4), controlPoint1: NSPoint(x: 5.5, y: 1.3), controlPoint2: NSPoint(x: 7.6, y: 0.9))
        p.line(to: NSPoint(x: 9.3, y: 7.1)); p.line(to: NSPoint(x: 9.1, y: 2.7))
        p.curve(to: NSPoint(x: 11.2, y: 2.6), controlPoint1: NSPoint(x: 9, y: 1.1), controlPoint2: NSPoint(x: 11, y: 1.2))
        p.line(to: NSPoint(x: 11.6, y: 7)); p.line(to: NSPoint(x: 12.1, y: 4))
        p.curve(to: NSPoint(x: 14, y: 4.4), controlPoint1: NSPoint(x: 12.4, y: 2.6), controlPoint2: NSPoint(x: 14.2, y: 3))
        p.line(to: NSPoint(x: 13.8, y: 10.3))
        p.curve(to: NSPoint(x: 15, y: 14.5), controlPoint1: NSPoint(x: 13.7, y: 11.9), controlPoint2: NSPoint(x: 14.8, y: 13.4))
        p.line(to: NSPoint(x: 16, y: 16.3)); p.line(to: NSPoint(x: 11.1, y: 19)); p.close()
        return p
    }

    private static func closedOutline() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 8.6, y: 18)); p.line(to: NSPoint(x: 6.6, y: 16))
        p.curve(to: NSPoint(x: 4.6, y: 13.6), controlPoint1: NSPoint(x: 5.6, y: 15.2), controlPoint2: NSPoint(x: 4.9, y: 14.5))
        p.line(to: NSPoint(x: 3.3, y: 10.6))
        p.curve(to: NSPoint(x: 5.2, y: 9.3), controlPoint1: NSPoint(x: 2.6, y: 9.1), controlPoint2: NSPoint(x: 4.4, y: 8.2))
        p.line(to: NSPoint(x: 5.9, y: 10.2)); p.line(to: NSPoint(x: 4.9, y: 7.7))
        p.curve(to: NSPoint(x: 7.2, y: 6.2), controlPoint1: NSPoint(x: 4.2, y: 5.8), controlPoint2: NSPoint(x: 6.2, y: 4.8))
        p.curve(to: NSPoint(x: 9.9, y: 5.8), controlPoint1: NSPoint(x: 7.1, y: 4.7), controlPoint2: NSPoint(x: 9.1, y: 4.3))
        p.curve(to: NSPoint(x: 12.6, y: 6.3), controlPoint1: NSPoint(x: 10.4, y: 4.6), controlPoint2: NSPoint(x: 12.2, y: 5))
        p.curve(to: NSPoint(x: 15, y: 8), controlPoint1: NSPoint(x: 13.8, y: 5.7), controlPoint2: NSPoint(x: 15, y: 6.7))
        p.line(to: NSPoint(x: 15.1, y: 10.8))
        p.curve(to: NSPoint(x: 15.1, y: 14), controlPoint1: NSPoint(x: 15.2, y: 12.1), controlPoint2: NSPoint(x: 14.7, y: 13))
        p.line(to: NSPoint(x: 16, y: 16.3)); p.line(to: NSPoint(x: 11.1, y: 19)); p.close()
        return p
    }
}
