import AppKit
import WebKit

/// One cached artwork family for all client hit targets. Local preview bundles
/// may supply a private trial pair; source/release bundles keep the base family.
enum WritingCursorRole: Equatable {
    case standard, clickable, text, drag, dragging, disabled, splitResize, columnResize
}

@MainActor
protocol WritingCursorProviding: AnyObject {
    var writingCursorRole: WritingCursorRole { get }
}

@MainActor
enum WritingCursors {
    private static let resources: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("EnglishX_EnglishX.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()
    private static let previewTheme: WritingCursorPreviewTheme? = {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".preview") == true,
              let directory = Bundle.main.resourceURL?.appendingPathComponent("CursorPreview") else { return nil }
        return WritingCursorPreviewTheme.load(from: directory)
    }()
    static let arrow = previewTheme?.arrow ?? load("richfree-cursor", hotspot: .zero, fallback: .arrow)
    static let pointer = previewTheme?.pointer ?? load("richfree-pointer", hotspot: NSPoint(x: 7, y: 3), fallback: .pointingHand)
    static let openHand = previewTheme?.pointer ?? WritingDragCursor.open
    static let closedHand = previewTheme?.pointer ?? WritingDragCursor.closed
    private static func load(_ name: String, hotspot: NSPoint, fallback: NSCursor) -> NSCursor {
        guard let url = resources.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return fallback }
        image.size = NSSize(width: 20, height: 20)
        return NSCursor(image: image, hotSpot: hotspot)
    }
    static func cursor(for role: WritingCursorRole) -> NSCursor {
        if let previewTheme { return previewTheme.cursor(for: role) }
        switch role {
        case .standard: return arrow
        case .clickable: return pointer
        case .text: return .iBeam
        case .drag: return openHand
        case .dragging: return closedHand
        case .disabled: return .operationNotAllowed
        case .splitResize: return .resizeUpDown
        case .columnResize: return .resizeLeftRight
        }
    }
    static func role(for target: NSView?) -> WritingCursorRole {
        var target = target
        while let view = target {
            if let owner = view as? WritingCursorProviding { return owner.writingCursorRole }
            if let text = view as? NSTextView { return text.isEditable || text.isSelectable ? .text : .standard }
            if let field = view as? NSTextField, field.isEditable || field.isSelectable { return .text }
            if let button = view as? NSButton { return button.isEnabled ? .clickable : .disabled }
            target = view.superview
        }
        return .standard
    }
    static func role(in window: NSWindow, at point: NSPoint) -> WritingCursorRole? {
        guard let content = window.contentView else { return nil }
        let local = content.convert(point, from: nil)
        guard content.bounds.contains(local) else { return nil }
        // Native resize edges take precedence over all client cursor styling.
        if window.styleMask.contains(.resizable), !window.styleMask.contains(.fullScreen),
           !content.bounds.insetBy(dx: 4, dy: 4).contains(local) { return nil }
        let parentPoint = content.superview?.convert(point, from: nil) ?? local
        let target = content.hitTest(parentPoint)
        // The shared paper tracking area also surrounds both browsers and the
        // dividers. Do not overwrite CSS cursors or AppKit's resize feedback.
        if target is NSSplitView { return nil }
        var ancestor = target
        while let view = ancestor {
            if view is WKWebView { return nil }
            ancestor = view.superview
        }
        return role(for: target)
    }
    @discardableResult
    static func update(in window: NSWindow, at point: NSPoint) -> Bool {
        guard let role = role(in: window, at: point) else { return false }
        let desired = cursor(for: role)
        guard NSCursor.current !== desired else { return false }
        desired.set()
        return true
    }
}

/// Retained once by each interactive surface. AppKit recomputes inVisibleRect;
/// no mouseMoved hook, cursor rectangles or per-layout area replacement.
/// Every owner resolves the same actual hit target, so nested areas agree.
@MainActor
final class WritingCursorTracking: NSObject {
    private weak var view: NSView?
    private var area: NSTrackingArea?
    init(view: NSView, activeWhenInactive: Bool = false) {
        self.view = view
        super.init()
        let activity: NSTrackingArea.Options = activeWhenInactive ? .activeAlways : .activeInKeyWindow
        let area = NSTrackingArea(rect: .zero, options: [.cursorUpdate, activity, .inVisibleRect], owner: self)
        view.addTrackingArea(area); self.area = area
    }
    func detach() {
        if let area { view?.removeTrackingArea(area) }
        area = nil
    }
    // NSTrackingArea sends this Objective-C selector to its NSObject owner.
    // Swift's inferred cursorUpdateWith: is not the AppKit callback.
    @objc(cursorUpdate:) func cursorUpdate(with event: NSEvent) {
        guard let window = view?.window else { return }
        WritingCursors.update(in: window, at: event.locationInWindow)
    }
}
