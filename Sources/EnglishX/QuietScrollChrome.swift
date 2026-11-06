import AppKit
import SwiftUI

struct ScrollEdges: Equatable {
    var above = false
    var below = false
}

/// Scoped to the nearest owning scroll view, never the app or system defaults.
struct QuietScrollChrome: NSViewRepresentable {
    var edgesChanged: (ScrollEdges) -> Void = { _ in }
    func makeNSView(context: Context) -> QuietScrollProbe {
        QuietScrollProbe(edgesChanged: edgesChanged)
    }
    func updateNSView(_ view: QuietScrollProbe, context: Context) {
        view.edgesChanged = edgesChanged
        view.scheduleUpdate()
    }
    static func dismantleNSView(_ view: QuietScrollProbe, coordinator: ()) { view.detach() }
}

final class QuietScrollProbe: NSView {
    var edgesChanged: (ScrollEdges) -> Void
    private weak var owner: NSScrollView?
    private weak var document: NSView?
    private var observers: [NSObjectProtocol] = []
    private var scheduled = false
    private var previous: ScrollEdges?
    init(edgesChanged: @escaping (ScrollEdges) -> Void) {
        self.edgesChanged = edgesChanged
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); scheduleUpdate() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); scheduleUpdate() }
    func scheduleUpdate() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            self.updateOwner()
        }
    }
    func detach() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        owner = nil; document = nil
    }
    private func updateOwner() {
        guard window != nil else { return }
        var ancestor = superview
        while let view = ancestor, !(view is NSScrollView) { ancestor = view.superview }
        guard let scroll = ancestor as? NSScrollView else { return }
        if owner !== scroll || document !== scroll.documentView {
            detach()
            owner = scroll; document = scroll.documentView
            scroll.contentView.postsBoundsChangedNotifications = true
            document?.postsFrameChangedNotifications = true
            for (notification, object) in [(NSView.boundsDidChangeNotification, scroll.contentView),
                                           (NSView.frameDidChangeNotification, scroll),
                                           (NSView.frameDidChangeNotification, scroll.documentView)] {
                guard let object else { continue }
                observers.append(NotificationCenter.default.addObserver(forName: notification, object: object, queue: .main) { [weak self] _ in
                    self?.scheduleUpdate()
                })
            }
        }
        if scroll.hasVerticalScroller { scroll.hasVerticalScroller = false }
        if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false }
        if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
        guard let document = scroll.documentView else { return }
        let visible = scroll.documentVisibleRect
        let bounds = document.bounds
        let overflow = bounds.height > visible.height + 1
        let low = overflow && visible.minY > bounds.minY + 1
        let high = overflow && visible.maxY < bounds.maxY - 1
        let edges = ScrollEdges(above: document.isFlipped ? low : high,
                                below: document.isFlipped ? high : low)
        if previous != edges { previous = edges; edgesChanged(edges) }
    }
}

struct QuietScrollEdgeMask: View {
    let edges: ScrollEdges
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(edges.above ? 0 : 1), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(edges.below ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
