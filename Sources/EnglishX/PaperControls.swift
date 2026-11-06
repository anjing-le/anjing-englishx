import AppKit
import SwiftUI

struct PaperOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}
struct PaperMenuRequest {
    let id: String
    let title: String
    let options: [PaperOption]
    let selected: String
    let choose: (String) -> Void
}
struct PaperMenuAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
@MainActor
final class PaperMenus: ObservableObject {
    @Published var request: PaperMenuRequest?
    @Published var highlighted = 0
    var isOpen: Bool { request != nil }
    func open(_ request: PaperMenuRequest) {
        if self.request?.id == request.id { close(); return }
        highlighted = request.options.firstIndex(where: { $0.value == request.selected }) ?? 0
        self.request = request
    }
    func close() { request = nil }
    func choose(_ index: Int) {
        guard let request, request.options.indices.contains(index) else { return }
        close(); request.choose(request.options[index].value)
    }
    func handleKey(_ event: NSEvent) -> Bool {
        guard let request else { return false }
        switch event.keyCode {
        case 53: close(); return true
        case 125: highlighted = min(request.options.count - 1, highlighted + 1); return true
        case 126: highlighted = max(0, highlighted - 1); return true
        case 36, 76, 49: if !event.isARepeat { choose(highlighted) }; return true
        case 123, 124: return true
        case 48: close(); return false
        default: return false
        }
    }
}

struct PaperChoice: View {
    @EnvironmentObject private var menus: PaperMenus
    @State private var anchorID = UUID().uuidString
    let title: String
    let value: String
    let options: [PaperOption]
    var compact = false
    let choose: (String) -> Void
    var body: some View {
        Button {
            menus.open(PaperMenuRequest(id: anchorID, title: title, options: options, selected: value, choose: choose))
        } label: {
            HStack(spacing: 10) {
                Text(options.first(where: { $0.value == value })?.label ?? value)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium))
            }
            .font(.system(size: compact ? 12 : 13))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, compact ? 9 : 13).padding(.vertical, compact ? 6 : 9)
            .background {
                ZStack {
                    PencilOutline(radius: 9).fill(Palette.ink).offset(x: 1.5, y: 2)
                    CrayonFill(color: Palette.paper).clipShape(PencilOutline(radius: 9))
                    PencilOutline(radius: 9).stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
        .buttonStyle(.plain)
        .anchorPreference(key: PaperMenuAnchors.self, value: .bounds) { [anchorID: $0] }
        .accessibilityLabel(title).accessibilityValue(options.first(where: { $0.value == value })?.label ?? value)
        .accessibilityHint("展开选项，可用上下键选择，回车确认，Esc 关闭")
    }
}

struct PaperMenuLayer: View {
    @ObservedObject var menus: PaperMenus
    let anchors: [String: Anchor<CGRect>]
    var body: some View {
        GeometryReader { geometry in
            if let request = menus.request {
                Color.clear.contentShape(Rectangle()).onTapGesture { menus.close() }
                if let anchor = anchors[request.id] {
                    let trigger = geometry[anchor]
                    let width = min(CGFloat(190), geometry.size.width - 32)
                    let height = min(CGFloat(request.options.count * 35 + 16), geometry.size.height - 48)
                    let x = min(max(16, trigger.minX), max(16, geometry.size.width - width - 16))
                    let below = trigger.maxY + 8
                    let y = below + height <= geometry.size.height - 12 ? below : max(30, trigger.minY - height - 8)
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(request.options.enumerated()), id: \.element.id) { index, option in
                                Button { menus.choose(index) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .medium))
                                            .opacity(option.value == request.selected ? 1 : 0)
                                        Text(option.label).font(.system(size: 13))
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 11).frame(height: 32)
                                    .background {
                                        if index == menus.highlighted {
                                            CrayonFill(color: Palette.sage.opacity(0.65)).clipShape(PencilOutline(radius: 7))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { if $0 { menus.highlighted = index } }
                                .accessibilityAddTraits(option.value == request.selected ? [.isSelected] : [])
                            }
                        }.padding(8)
                        .background { QuietScrollChrome() }
                    }
                    .scrollIndicators(.hidden)
                    .frame(width: width, height: height)
                    .background {
                        ZStack {
                            PencilOutline(radius: 12).fill(Palette.ink).offset(x: 3, y: 4)
                            CrayonFill(color: Palette.paper).clipShape(PencilOutline(radius: 12))
                            PencilOutline(radius: 12).stroke(Palette.ink, lineWidth: 1.8)
                        }
                    }
                    .position(x: x + width / 2, y: y + height / 2)
                    .accessibilityLabel(request.title)
                }
            }
        }
    }
}

struct PaperTimeline: View {
    @Binding var value: Double
    let duration: Double
    let editing: (Bool) -> Void
    @State private var dragging = false
    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 12)
            let fraction = min(1, max(0, value / max(0.001, duration)))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.35)).frame(height: 3)
                CrayonFill(color: Palette.yellow).frame(width: width * fraction, height: 3)
                    .clipShape(Capsule())
                Circle().fill(Palette.paper)
                    .overlay { Circle().stroke(Palette.ink.opacity(0.8), lineWidth: 1.5) }
                    .frame(width: 11, height: 11).offset(x: width * fraction - 5.5)
            }
            .padding(.horizontal, 6)
            .frame(height: 22)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                if !dragging { dragging = true; editing(true) }
                value = min(1, max(0, (gesture.location.x - 6) / width)) * duration
            }.onEnded { _ in dragging = false; editing(false) })
        }
        .frame(height: 22).focusable()
        .accessibilityLabel("播放进度").accessibilityValue("\(Int(value)) 秒，共 \(Int(duration)) 秒")
        .accessibilityAdjustableAction { direction in
            value = min(duration, max(0, value + (direction == .increment ? 1 : -1)))
        }
        .onDisappear { if dragging { dragging = false; editing(false) } }
    }
}
