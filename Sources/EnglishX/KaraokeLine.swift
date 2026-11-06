import SwiftUI

struct TimedWord: Identifiable {
    let id: Int
    let text: String
    let start: Double
    let end: Double

    func progress(at time: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        return min(1, max(0, (time - start) / (end - start)))
    }
}

/// Both glyph layers share the same measured word. Only the foreground mask
/// changes; the timeline never changes glyph metrics, line wrapping or layout.
struct KaraokeLine: View {
    let words: [TimedWord]
    let time: Double
    let active: Bool

    var body: some View {
        WordWrap(spacing: 6, lineSpacing: 5) {
            ForEach(words) { word in
                let progress = active ? word.progress(at: time) : 0
                Text(word.text)
                    .foregroundStyle(Palette.ink.opacity(active ? 1 : 0.52))
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Text(word.text)
                                .foregroundStyle(Palette.spoken)
                                .mask(alignment: .leading) {
                                    Rectangle().frame(width: geometry.size.width * progress)
                                }
                        }
                        .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    .fixedSize()
            }
        }
        .font(.custom("AvenirNext-Medium", size: active ? 25 : 23))
        // No implicit tween: seeking and pausing must take effect immediately.
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(words.map(\.text).joined(separator: " "))
    }
}

/// Wrap at word boundaries, without splitting contractions or punctuation.
private struct WordWrap: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, view) in subviews.enumerated() {
            let origin = result.origins[index]
            view.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                       anchor: .topLeading, proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat?, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let limit = width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        var origins: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > limit {
                x = 0; y += rowHeight + lineSpacing; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width ?? usedWidth, height: y + rowHeight), origins)
    }
}
