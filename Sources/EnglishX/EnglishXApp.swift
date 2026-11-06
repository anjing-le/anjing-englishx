import AppKit
import SwiftUI

@main
struct EnglishXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("显示 EnglishX") { delegate.showWindow() }
                }
                CommandGroup(replacing: .appSettings) {
                    Button("设置…") { delegate.openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
                CommandGroup(after: .windowArrangement) {
                    Button("关闭窗口") { NSApp.keyWindow?.performClose(nil) }
                        .keyboardShortcut("w", modifiers: .command)
                    Button("最小化") { NSApp.keyWindow?.performMiniaturize(nil) }
                        .keyboardShortcut("m", modifiers: .command)
                    Button("切换全屏") { NSApp.keyWindow?.toggleFullScreen(nil) }
                        .keyboardShortcut("f", modifiers: [.control, .command])
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: PaperWindow?
    private let model = LearningMockModel()
    private let route = EnglishXRoute()
    private let processing = ProcessingSettingsModel()
    private let menus = PaperMenus()
    private var keyboardMonitor: Any?
    private var pointerMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        processing.onImported = { [weak self] id in self?.model.refreshLibrary(selectPackage: id) }
        let window = PaperWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760))
        window.onClose = { [weak self] in
            self?.model.isPlaying = false
            self?.processing.review?.stopPreview()
            self?.menus.close()
            self?.processing.rules.close()
        }
        let paper = PaperView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760))
        let host = NSHostingView(rootView: EnglishXRootView(route: route, learning: model, processing: processing, menus: menus))
        host.frame = paper.bounds
        host.autoresizingMask = [.width, .height]
        paper.addSubview(host, positioned: .below, relativeTo: paper.subviews.first)
        window.contentView = paper
        pointerMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if event.window === self?.window { self?.model.keyboardNavigating = false }
            return event
        }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            // Borderless windows cannot rely on SwiftUI's menu shortcut routing.
            // Leave sheets to AppKit so Cmd+W never closes their parent window.
            if event.keyCode == 13,
               event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
               self.window?.attachedSheet == nil {
                self.window?.performClose(nil)
                return nil
            }
            guard
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  self.window?.attachedSheet == nil else { return event }
            if self.menus.isOpen {
                return self.menus.handleKey(event) ? nil : event
            }
            if self.route.settingsVisible {
                if event.keyCode == 53 {
                    if let editor = self.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
                    if self.processing.rules.isVisible { self.processing.rules.close(); return nil }
                    if self.processing.reviewVisible, let review = self.processing.review {
                        if review.saving { review.cancel() }
                        else { review.stopPreview(); self.processing.reviewVisible = false }
                        return nil
                    }
                    self.route.settingsVisible = false; return nil
                }
                return event
            }
            if let editor = self.window?.firstResponder as? NSTextView,
               editor.isEditable || editor.hasMarkedText() { return event }
            if self.window?.firstResponder is NSSlider { return event }
            if self.window?.firstResponder is SplitHandleView,
               [123, 124, 125, 126].contains(event.keyCode) { return event }
            if event.keyCode == 48 { self.model.keyboardNavigating = true; self.model.revealControls(); return event }
            switch event.keyCode {
            case 49: if !event.isARepeat { self.model.toggle() }; return nil
            case 123: self.model.jump(-self.model.step); return nil
            case 124: self.model.jump(self.model.step); return nil
            case 53: self.model.libraryVisible = false; return event
            default: return event
            }
        }
        window.center()
        self.window = window
        showWindow()
    }
    func applicationWillTerminate(_ notification: Notification) { processing.cancelProcessing() }
    func openSettings() {
        model.isPlaying = false
        model.libraryVisible = false
        menus.close()
        route.settingsVisible = true
        window?.makeFirstResponder(nil)
        showWindow()
    }
    func showWindow() {
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }
}

final class PaperWindow: NSWindow {
    var onClose: (() -> Void)?
    private var restoredFrame: NSRect?
    private var maximizedFrame: NSRect?
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        title = "EnglishX"
        contentMinSize = NSSize(width: 420, height: 420)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior.insert(.fullScreenPrimary)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func performClose(_ sender: Any?) { if attachedSheet == nil { close() } }
    override func close() {
        onClose?()
        super.close()
    }
    override func performMiniaturize(_ sender: Any?) { miniaturize(sender) }
    func toggleDesktopMaximize() {
        guard !styleMask.contains(.fullScreen), let visible = screen?.visibleFrame else { return }
        let target: NSRect
        if let restoredFrame, let maximizedFrame, frame.equalTo(maximizedFrame) {
            var restored = restoredFrame
            restored.size.width = min(restored.width, visible.width)
            restored.size.height = min(restored.height, visible.height)
            restored.origin.x = min(max(restored.minX, visible.minX), visible.maxX - restored.width)
            restored.origin.y = min(max(restored.minY, visible.minY), visible.maxY - restored.height)
            target = restored
            self.restoredFrame = nil
            self.maximizedFrame = nil
        } else {
            restoredFrame = frame
            maximizedFrame = visible
            target = visible
        }
        setFrame(target, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

final class PaperView: NSView {
    private let dragRegion = DragRegion()
    private var cursorTracking: WritingCursorTracking!
    private static let texture: NSImage? = {
        let shipped = Bundle.main.resourceURL?.appendingPathComponent("EnglishX_EnglishX.bundle")
        let resources = shipped.flatMap(Bundle.init(url:)) ?? Bundle.module
        return resources.url(forResource: "PaperTexture", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }()
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        addSubview(dragRegion)
        cursorTracking = WritingCursorTracking(view: self)
        setAccessibilityElement(false)
        setAccessibilityRole(.group)
        setAccessibilityLabel("EnglishX 学习空间")
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        dragRegion.frame = NSRect(x: 12, y: 0, width: max(0, bounds.width - 24), height: 28)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        (dark ? NSColor(calibratedWhite: 0.105, alpha: 1) : NSColor(calibratedRed: 0.99, green: 0.987, blue: 0.975, alpha: 1)).setFill()
        bounds.fill()
        Self.texture?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: dark ? 0.035 : 0.32)
    }
}

final class DragRegion: NSView, WritingCursorProviding {
    private var cursorTracking: WritingCursorTracking!
    private var isDragging = false
    var writingCursorRole: WritingCursorRole {
        if window?.styleMask.contains(.fullScreen) == true { return .standard }
        return isDragging ? .dragging : .drag
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
        cursorTracking = WritingCursorTracking(view: self, activeWhenInactive: true)
    }
    required init?(coder: NSCoder) { nil }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard let window = window as? PaperWindow, !window.styleMask.contains(.fullScreen) else { return }
        if event.clickCount == 2 { window.toggleDesktopMaximize(); return }
        isDragging = true
        WritingCursors.closedHand.push()
        defer {
            isDragging = false
            NSCursor.pop()
            WritingCursors.update(in: window, at: window.mouseLocationOutsideOfEventStream)
        }
        window.performDrag(with: event)
    }
}
