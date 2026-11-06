import AppKit
import SwiftUI
import Combine
import AVFoundation

// All dialogue below is original mock content, never a claimed transcription.
struct DialogueLine: Identifiable {
    let id: Int
    let start: Double
    let end: Double
    let speaker: String
    let text: String
    let words: [TimedWord]
    var speakerID: String? = nil
    var speakerEvidence: String? = nil
    var speakerNeedsReview = false
    init(id: Int, start: Double, end: Double, speaker: String, text: String, words: [TimedWord],
         speakerID: String? = nil, speakerEvidence: String? = nil, speakerNeedsReview: Bool = false) {
        self.id = id; self.start = start; self.end = end; self.speaker = speaker; self.text = text; self.words = words
        self.speakerID = speakerID; self.speakerEvidence = speakerEvidence; self.speakerNeedsReview = speakerNeedsReview
    }
    init(id: Int, start: Double, end: Double, speaker: String, text: String, cues: [(Double, Double)]) {
        self.id = id; self.start = start; self.end = end; self.speaker = speaker; self.text = text
        let tokens = text.split(separator: " ").map(String.init)
        precondition(tokens.count == cues.count, "Each mock word needs its own explicit timing")
        var previousEnd = 0.0
        words = zip(tokens, cues).enumerated().map { index, pair in
            let (token, cue) = pair
            precondition(cue.0 >= previousEnd && cue.1 > cue.0 && cue.1 <= end - start)
            previousEnd = cue.1
            return TimedWord(id: index, text: token, start: start + cue.0, end: start + cue.1)
        }
    }
}

struct StudyClip: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let duration: Double
    let tint: Color
    let lines: [DialogueLine]
    var mediaURL: URL? = nil
    var notes: [[WordExplanation]]? = nil
    var attribution: ClipPackage.Attribution? = nil
    var packageID: String? = nil

    func isTrailing(_ line: DialogueLine) -> Bool {
        // Unknown alternation is visual only; identified characters keep their first-appearance side.
        guard line.speaker != "未标注" else { return line.id % 2 == 1 }
        var identities: [String] = []
        for item in lines where item.speaker != "未标注" {
            let key = item.speakerID ?? item.speaker
            if !identities.contains(key) { identities.append(key) }
        }
        return (identities.firstIndex(of: line.speakerID ?? line.speaker) ?? 0) % 2 == 1
    }

    static let examples: [StudyClip] = [
        StudyClip(id: 0, name: "雨天的约定", subtitle: "雨声、闲聊，还有一段回家的路", duration: 32, tint: Palette.blue, lines: [
            .init(id: 0, start: 0, end: 5, speaker: "A", text: "Did you bring an umbrella?", cues: [(0.15, 0.55), (0.65, 1.05), (1.18, 1.9), (2.05, 2.35), (2.5, 4.25)]),
            .init(id: 1, start: 5, end: 10, speaker: "B", text: "No. I thought the rain would stop.", cues: [(0.12, 0.65), (0.95, 1.15), (1.3, 1.95), (2.1, 2.3), (2.45, 2.95), (3.1, 3.5), (3.7, 4.65)]),
            .init(id: 2, start: 10, end: 16, speaker: "A", text: "Then let's take the long way home.", cues: [(0.15, 0.65), (0.8, 1.4), (1.6, 2.1), (2.25, 2.6), (2.75, 3.7), (3.85, 4.6), (4.9, 5.8)]),
            .init(id: 3, start: 16, end: 21, speaker: "B", text: "The long way? We'll get soaked.", cues: [(0.1, 0.4), (0.55, 1.25), (1.4, 2.1), (2.35, 2.9), (3.05, 3.5), (3.7, 4.8)]),
            .init(id: 4, start: 21, end: 27, speaker: "A", text: "I know a place where we can wait.", cues: [(0.12, 0.4), (0.55, 1.2), (1.4, 1.6), (1.8, 2.6), (2.8, 3.3), (3.45, 3.75), (3.9, 4.4), (4.65, 5.8)]),
            .init(id: 5, start: 27, end: 32, speaker: "B", text: "All right. Lead the way.", cues: [(0.15, 0.6), (0.75, 1.4), (1.7, 2.5), (2.7, 3.1), (3.35, 4.65)])
        ]),
        StudyClip(id: 1, name: "再坐一会儿", subtitle: "一杯热茶，不着急的下午", duration: 24, tint: Palette.peach, lines: [
            .init(id: 0, start: 0, end: 4, speaker: "A", text: "Do you have to leave already?", cues: [(0.1, 0.4), (0.5, 0.85), (0.95, 1.35), (1.5, 1.8), (1.95, 2.45), (2.65, 3.8)]),
            .init(id: 1, start: 4, end: 9, speaker: "B", text: "I guess I could stay a little longer.", cues: [(0.12, 0.3), (0.45, 0.95), (1.1, 1.3), (1.45, 1.9), (2.05, 2.55), (2.7, 2.85), (3.0, 3.65), (3.8, 4.8)]),
            .init(id: 2, start: 9, end: 14, speaker: "A", text: "Good. The tea is still warm.", cues: [(0.15, 0.75), (1.05, 1.25), (1.4, 1.9), (2.1, 2.4), (2.6, 3.1), (3.4, 4.7)]),
            .init(id: 3, start: 14, end: 19, speaker: "B", text: "You always know what to say.", cues: [(0.12, 0.5), (0.65, 1.4), (1.55, 2.1), (2.3, 2.75), (2.9, 3.2), (3.45, 4.7)]),
            .init(id: 4, start: 19, end: 24, speaker: "A", text: "Only when there's tea involved.", cues: [(0.12, 0.85), (1.0, 1.45), (1.6, 2.3), (2.5, 3.1), (3.3, 4.8)])
        ])
    ]
}

@MainActor
final class LearningMockModel: ObservableObject {
    @Published var clipIndex = 0
    @Published var time: Double = 13.2 {
        didSet { if !observingPlayer, player != nil { seekPlayer(to: time) } }
    }
    @Published var isPlaying = false {
        didSet { if isPlaying { player?.playImmediately(atRate: Float(speed)) } else { player?.pause() } }
    }
    @Published var speed: Double = 1 {
        didSet { if isPlaying { player?.rate = Float(speed) } }
    }
    @Published private(set) var clips = StudyClip.examples
    @Published private(set) var player: AVPlayer?
    private var playerObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var observingPlayer = false
    private var seeking = false
    private var seekID = UUID()
    init(loadLibrary: Bool = true) { if loadLibrary { refreshLibrary() } }
    func refreshLibrary(selectPackage: String? = nil) {
        let stored = ClipLibrary.load()
        let oldPackage = clips.indices.contains(clipIndex) ? clips[clipIndex].packageID : nil
        clips = StudyClip.examples + stored
        if let target = selectPackage ?? oldPackage, let index = clips.firstIndex(where: { $0.packageID == target }) {
            select(index)
        } else if !stored.isEmpty { select(StudyClip.examples.count) }
    }
    private func configurePlayer() {
        if let playerObserver { player?.removeTimeObserver(playerObserver); self.playerObserver = nil }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
        player?.pause(); player = nil
        guard let url = clip.mediaURL else { return }
        let current = AVPlayer(url: url); player = current
        playerObserver = current.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0/30, preferredTimescale: 600), queue: .main) { [weak self, weak current] value in
            Task { @MainActor in
                guard let self, self.player === current, !self.seeking else { return }
                let seconds = value.seconds
                guard seconds.isFinite else { return }
                self.observingPlayer = true; self.time = min(self.clip.duration, max(0, seconds)); self.observingPlayer = false
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: current.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.isPlaying = false
                self.observingPlayer = true; self.time = self.clip.duration; self.observingPlayer = false
            }
        }
    }
    private func seekPlayer(to seconds: Double) {
        guard let player else { return }
        seeking = true; let id = UUID(); seekID = id
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in if self?.seekID == id { self?.seeking = false } }
        }
    }
    @Published var step: Double = 1
    @Published var libraryVisible = false
    @Published var videoHovered = false
    @Published var controlFocused = false
    @Published var keyboardNavigating = false
    @Published var menuTracking = false
    @Published var scrubbing = false
    @Published private var transientControls = false
    private var hideAfter = Date.distantPast
    private var lastTick = Date()
    var controlsVisible: Bool { videoHovered || (controlFocused && keyboardNavigating) || menuTracking || scrubbing || transientControls }
    func revealControls(for duration: TimeInterval = 1.8) {
        hideAfter = Date().addingTimeInterval(duration)
        if !transientControls { transientControls = true }
    }
    func hoverVideo(_ hovering: Bool) {
        videoHovered = hovering
        if !hovering { revealControls(for: 0.45) }
    }
    var clip: StudyClip { clips[clipIndex] }
    var activeID: Int { clip.lines.last(where: { time >= $0.start })?.id ?? 0 }
    func select(_ index: Int) {
        guard clips.indices.contains(index) else { return }
        isPlaying = false; clipIndex = index; configurePlayer(); time = 0
    }
    func toggle() {
        if time >= clip.duration { time = 0 }
        isPlaying.toggle(); lastTick = Date(); revealControls()
    }
    func jump(_ delta: Double, reveal: Bool = true) {
        if reveal { revealControls() }
        time = min(clip.duration, max(0, time + delta))
        if time >= clip.duration { isPlaying = false }
    }
    func tick(_ now: Date) {
        defer { lastTick = now }
        if transientControls, now >= hideAfter { transientControls = false }
        guard player == nil, isPlaying, NSApp.isActive else { return }
        advance(by: min(0.2, max(0, now.timeIntervalSince(lastTick))))
    }
    func advance(by elapsed: Double) {
        guard isPlaying else { return }
        jump(max(0, elapsed) * speed, reveal: false)
    }
}

// Product colors, intentionally matte, with warm dark equivalents.
enum Palette {
    static let ink = color(0x302F29, 0xE8E1CE)
    static let muted = color(0x888274, 0xB6AE9C)
    static let paper = color(0xFBFAF3, 0x272824)
    static let yellow = color(0xF0D780, 0x8C7A40)
    static let sage = color(0xC4CEAE, 0x59654B)
    static let peach = color(0xECC5B5, 0x825F52)
    static let blue = color(0xB9D1DB, 0x4F6874)
    static let spoken = color(0xD6663D, 0xF4A17C)
    static let lilac = color(0xCFC4DF, 0x6D607E)
    static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static func handwriting(_ size: CGFloat) -> Font { .custom("HanziPenSC-W3", size: size) }
}

// Stable, slightly uneven contours. No frame-to-frame random jitter.
struct PencilOutline: Shape {
    var radius: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 3)
        let x = rect.minX, y = rect.minY, w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: x+r, y: y+1))
        p.addCurve(to: CGPoint(x: x+w-r, y: y+1), control1: CGPoint(x: x+w*0.35, y: y-1), control2: CGPoint(x: x+w*0.7, y: y+2))
        p.addQuadCurve(to: CGPoint(x: x+w-1, y: y+r), control: CGPoint(x: x+w+1, y: y-1))
        p.addCurve(to: CGPoint(x: x+w-1, y: y+h-r), control1: CGPoint(x: x+w+1, y: y+h*0.4), control2: CGPoint(x: x+w-2, y: y+h*0.7))
        p.addQuadCurve(to: CGPoint(x: x+w-r, y: y+h-1), control: CGPoint(x: x+w+1, y: y+h))
        p.addCurve(to: CGPoint(x: x+r, y: y+h-1), control1: CGPoint(x: x+w*0.6, y: y+h+1), control2: CGPoint(x: x+w*0.3, y: y+h-2))
        p.addQuadCurve(to: CGPoint(x: x+1, y: y+h-r), control: CGPoint(x: x-1, y: y+h+1))
        p.addCurve(to: CGPoint(x: x+1, y: y+r), control1: CGPoint(x: x-1, y: y+h*0.65), control2: CGPoint(x: x+2, y: y+h*0.3))
        p.addQuadCurve(to: CGPoint(x: x+r, y: y+1), control: CGPoint(x: x-1, y: y-1))
        p.closeSubpath()
        return p
    }
}

struct CrayonFill: View {
    var color: Color
    var body: some View {
        color.overlay {
            if let image = PaperResources.texture {
                Image(nsImage: image).resizable().blendMode(.multiply).opacity(0.38)
            }
        }
    }
}

// The label is layered above its painted shape, rather than glass or gradients.
struct PaintedButtonStyle: ButtonStyle {
    var color: Color = Palette.paper
    var large = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 17 : 13, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, large ? 22 : 13).padding(.vertical, large ? 13 : 10)
            .background {
                ZStack {
                    PencilOutline(radius: 12).fill(Palette.ink).offset(x: 2, y: 3)
                    CrayonFill(color: color).clipShape(PencilOutline(radius: 12))
                    PencilOutline(radius: 12).stroke(Palette.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 2 : 0)
    }
}

struct LearningMockView: View {
    @ObservedObject var model: LearningMockModel
    var importVideo: ([NSItemProvider]) -> Bool = { _ in false }
    var acceptingVideo = true
    @State private var videoDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum PlayerFocus: Hashable { case surface, timeline, back, play, forward, speed, step }
    @FocusState private var playerFocus: PlayerFocus?
    @AppStorage("study.topFraction") private var savedTopFraction: Double = 0.735
    @State private var draggingTopFraction: Double?
    @AppStorage("study.videoFraction") private var savedVideoFraction: Double = 0.55
    @State private var draggingVideoFraction: Double?
    @State private var dialogueScrollEdges = ScrollEdges()
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                let metrics = StudySplitMetrics(contentHeight: geometry.size.height - 70)
                let fraction = draggingTopFraction ?? savedTopFraction
                let topHeight = metrics.topHeight(fraction: fraction)
                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        if geometry.size.width >= 800 {
                            let columns = StudyColumnMetrics(contentWidth: geometry.size.width - 76)
                            let videoWidth = columns.videoWidth(fraction: draggingVideoFraction ?? savedVideoFraction)
                            HStack(alignment: .top, spacing: 9) {
                                player(compact: false).frame(width: videoWidth, height: topHeight)
                                StudySplitHandle(axis: .horizontal, topHeight: videoWidth,
                                                 fraction: columns.fraction(for: videoWidth),
                                                 resize: { draggingVideoFraction = columns.fraction(for: $0) },
                                                 finish: {
                                                     if let draggingVideoFraction { savedVideoFraction = draggingVideoFraction }
                                                     draggingVideoFraction = nil
                                                 })
                                    .frame(width: 18).padding(.vertical, 18)
                                lyrics.frame(width: columns.availableWidth - videoWidth, height: topHeight)
                            }
                        } else {
                            ScrollView {
                                VStack(spacing: 20) {
                                    player(compact: true)
                                    lyrics.frame(height: 320)
                                }
                                .padding(.bottom, 6)
                            }.scrollIndicators(.hidden)
                        }
                    }.frame(height: topHeight)
                    StudySplitHandle(topHeight: topHeight,
                                     fraction: metrics.fraction(for: topHeight),
                                     resize: { draggingTopFraction = metrics.fraction(for: $0) },
                                     finish: {
                                         if let draggingTopFraction { savedTopFraction = draggingTopFraction }
                                         draggingTopFraction = nil
                                     })
                        .frame(height: 18).padding(.horizontal, 18)
                    WordStudyDetail(model: model)
                        .frame(maxWidth: .infinity)
                        .frame(height: metrics.availableHeight - topHeight)
                }
                .padding(.horizontal, geometry.size.width >= 800 ? 38 : 26)
                .padding(.top, 46).padding(.bottom, 24)
                if model.libraryVisible {
                    Palette.ink.opacity(0.10).ignoresSafeArea()
                        .onTapGesture { setLibrary(false) }
                    library.frame(width: min(285, geometry.size.width - 28))
                        .padding(.top, 36).padding(.leading, 12).padding(.bottom, 12)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .onReceive(ticker) { model.tick($0) }
        .onChange(of: playerFocus) { _, value in model.controlFocused = value != nil }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            if model.controlsVisible { model.menuTracking = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            model.menuTracking = false
            model.revealControls(for: 0.6)
        }
    }

    private func setLibrary(_ visible: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { model.libraryVisible = visible }
    }

    private func player(compact: Bool) -> some View {
        Group {
            if compact {
                videoSurface.aspectRatio(1.48, contentMode: .fit)
            } else {
                videoSurface
            }
        }
    }

    private var videoSurface: some View {
        GeometryReader { geometry in
        ZStack {
            PencilOutline(radius: 22).fill(Palette.ink).offset(x: 5, y: 6)
            ZStack(alignment: .bottom) {
                Group {
                    if let player = model.player {
                        LocalVideoView(player: player).accessibilityLabel("本地视频")
                    } else {
                        Image(nsImage: PaperResources.scene).resizable().aspectRatio(contentMode: .fill)
                            .accessibilityLabel("蜡笔雨天窗景，示例视频占位画面")
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                Color.clear.contentShape(Rectangle())
                    .focusable().focused($playerFocus, equals: .surface)
                    .accessibilityLabel("视频播放区")
                    .onTapGesture { model.toggle() }
                playerControls
                    .padding(.horizontal, 16).padding(.bottom, 12).padding(.top, 32)
                    .background {
                        LinearGradient(colors: [.clear, Color.black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
                    }
                    .opacity(model.controlsVisible ? 1 : 0)
                    .allowsHitTesting(model.controlsVisible)
                    .disabled(!model.controlsVisible)
                    .accessibilityHidden(!model.controlsVisible)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.controlsVisible)
            }
            .clipShape(PencilOutline(radius: 22))
            PencilOutline(radius: 22).stroke(Palette.ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .overlay(alignment: .topLeading) {
            Button { setLibrary(true) } label: { Image(systemName: "sidebar.left") }
                .buttonStyle(PaintedButtonStyle(color: Palette.sage))
                .accessibilityLabel("打开片段库").help("片段库")
                .padding(14)
        }
        .contentShape(PencilOutline(radius: 22))
        .background { VideoHoverRegion { model.hoverVideo($0) } }
        .overlay {
            if videoDropTargeted {
                CrayonFill(color: Palette.sage.opacity(0.85)).clipShape(PencilOutline(radius: 22))
                    .overlay { Text(acceptingVideo ? "松开放入视频" : "加工中，稍后再添加").font(Palette.handwriting(25)) }
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $videoDropTargeted) { acceptingVideo && importVideo($0) }
    }

    private var playerControls: some View {
        VStack(spacing: 8) {
            PaperTimeline(value: $model.time, duration: model.clip.duration) { editing in
                model.scrubbing = editing
                model.revealControls()
            }
            .focused($playerFocus, equals: .timeline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    transportControls
                    Text("\(timestamp(model.time)) / \(timestamp(model.clip.duration))")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.white.opacity(0.9))
                        .fixedSize()
                    Spacer(minLength: 4)
                    playbackMenus
                }
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        transportControls
                        Spacer(minLength: 0)
                        Text("\(timestamp(model.time)) / \(timestamp(model.clip.duration))")
                            .font(.system(size: 11)).monospacedDigit().foregroundStyle(.white.opacity(0.9))
                    }
                    HStack { playbackMenus; Spacer(minLength: 0) }
                }
            }
        }
    }

    private var transportControls: some View {
        Group {
            Button { model.toggle() } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17)).frame(width: 24, height: 28)
            }
            .focused($playerFocus, equals: .play)
            .accessibilityLabel(model.isPlaying ? "暂停" : "播放")
            Button { model.jump(-model.step) } label: {
                Image(systemName: "gobackward").font(.system(size: 17)).frame(width: 24, height: 28)
            }
            .focused($playerFocus, equals: .back)
            .accessibilityLabel("后退 \(Int(model.step)) 秒")
            Button { model.jump(model.step) } label: {
                Image(systemName: "goforward").font(.system(size: 17)).frame(width: 24, height: 28)
            }
            .focused($playerFocus, equals: .forward)
            .accessibilityLabel("前进 \(Int(model.step)) 秒")
        }
        .buttonStyle(.plain).foregroundStyle(.white)
    }

    private var playbackMenus: some View {
        Group {
            PaperChoice(title: "播放速度", value: String(model.speed),
                        options: [0.5, 0.75, 1.0, 1.25].map { PaperOption(value: String($0), label: "\($0.formatted())×") }, compact: true) {
                if let speed = Double($0) { model.speed = speed; model.revealControls() }
            }.focused($playerFocus, equals: .speed)
            PaperChoice(title: "跳转步长", value: String(model.step),
                        options: [1.0, 2.0, 3.0, 5.0].map { PaperOption(value: String($0), label: "\(Int($0))s") }, compact: true) {
                if let step = Double($0) { model.step = step; model.revealControls() }
            }.focused($playerFocus, equals: .step)
        }.fixedSize()
    }

    private var lyrics: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(model.clip.lines) { line in
                            dialogue(line).id(line.id)
                        }
                    }.padding(.horizontal, 8).padding(.vertical, 10)
                        .background { QuietScrollChrome { dialogueScrollEdges = $0 } }
                }
                .scrollIndicators(.hidden)
                .mask { QuietScrollEdgeMask(edges: dialogueScrollEdges) }
                .onAppear { DispatchQueue.main.async { proxy.scrollTo(model.activeID, anchor: model.activeID == 0 ? .top : .center) } }
                .onChange(of: model.clipIndex) { _, _ in DispatchQueue.main.async { proxy.scrollTo(model.activeID, anchor: model.activeID == 0 ? .top : .center) } }
                .onChange(of: model.activeID) { _, value in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { proxy.scrollTo(value, anchor: value == 0 ? .top : .center) }
                }
            }
        }
    }

    private func dialogue(_ line: DialogueLine) -> some View {
        let active = line.id == model.activeID
        let unknown = line.speaker == "未标注"
        let trailing = model.clip.isTrailing(line)
        let color = active ? Palette.yellow.opacity(0.6) : (trailing ? Palette.blue.opacity(0.33) : Palette.sage.opacity(0.33))
        return HStack(alignment: .top, spacing: 0) {
            if trailing { Spacer(minLength: 64) }
            VStack(alignment: trailing ? .trailing : .leading, spacing: 7) {
                HStack(spacing: 9) {
                    Text(unknown ? "待确认" : (line.speaker == "A" || line.speaker == "B" ? "说话人 " + line.speaker : line.speaker))
                    if line.speakerNeedsReview { Text("待核对").font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.75)) }
                    Text(timestamp(line.start)).monospacedDigit().foregroundStyle(Palette.muted)
                }.font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.horizontal, 14)
                    .help(line.speakerEvidence.map { (unknown ? "未确定说话人：" : (line.speakerNeedsReview ? "自动角色建议：" : "人工确认：")) + $0 } ?? "")
                Button {
                    model.time = line.start; model.revealControls()
                } label: {
                    KaraokeLine(words: line.words, time: model.time, active: active)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.top, 13).padding(.bottom, 20)
                        .background {
                            DialogueBubble(trailing: trailing).fill(Palette.ink.opacity(active ? 0.17 : 0.07)).offset(x: 1.5, y: 2)
                            CrayonFill(color: color).clipShape(DialogueBubble(trailing: trailing))
                            DialogueBubble(trailing: trailing).stroke(Palette.ink.opacity(active ? 0.6 : 0.25),
                                style: StrokeStyle(lineWidth: active ? 1.6 : 1.1, lineCap: .round, lineJoin: .round))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(line.speaker)\(line.speakerNeedsReview ? "，自动识别待核对" : "")，\(timestamp(line.start))，\(line.text)")
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
            if !trailing { Spacer(minLength: 64) }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack {
                Text("我的片段").font(Palette.handwriting(26))
                Spacer()
                Button { setLibrary(false) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("收起片段库")
            }
            ScrollView {
            VStack(spacing: 18) {
            ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                Button {
                    model.select(index); setLibrary(false)
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 5).fill(clip.tint).frame(height: 8)
                        Text(clip.name).font(Palette.handwriting(22))
                        Text("\(clip.mediaURL == nil ? "示例" : clip.subtitle) · \(timestamp(clip.duration))")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background { CrayonFill(color: index == model.clipIndex ? Palette.yellow.opacity(0.35) : Palette.paper).clipShape(PencilOutline(radius: 12)) }
                        .overlay { PencilOutline(radius: 12).stroke(Palette.ink.opacity(index == model.clipIndex ? 1 : 0.25), lineWidth: 1.5) }
                }.buttonStyle(.plain)
            }
            }
            }.scrollIndicators(.hidden)
            if let credit = model.clip.attribution {
                Text(credit.credit + " · " + credit.license).font(.system(size: 10)).foregroundStyle(Palette.muted)
                if let url = URL(string: credit.source) { Link("来源与授权", destination: url).font(.system(size: 11)) }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background {
            ZStack {
                PencilOutline(radius: 16).fill(Palette.ink).offset(x: 4, y: 4)
                CrayonFill(color: Palette.paper).clipShape(PencilOutline(radius: 16))
                PencilOutline(radius: 16).stroke(Palette.ink, lineWidth: 2)
            }
        }
    }

    private func timestamp(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// One cached crayon drawing for the video placeholder. No lettering or people.
@MainActor
enum PaperResources {
    static let resources: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("EnglishX_EnglishX.bundle"), let bundle = Bundle(url: url) { return bundle }
        return .module
    }()
    static let texture = resources.url(forResource: "PaperTexture", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    static let scene: NSImage = {
        let size = NSSize(width: 900, height: 610)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(red: 0.94, green: 0.9, blue: 0.8, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        var seed: UInt64 = 73
        func random() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1; return CGFloat((seed >> 32) & 0xffff) / 65535 }
        func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
            NSColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: alpha)
        }
        func line(_ points: [NSPoint], color c: NSColor, width: CGFloat) {
            let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; c.setStroke(); path.stroke()
        }
        func scribble(_ rect: NSRect, hex: UInt32, count: Int) {
            for _ in 0..<count {
                let x = rect.minX + random()*rect.width, y = rect.minY + random()*rect.height
                let end = NSPoint(x: min(rect.maxX, x+4+random()*26), y: min(rect.maxY, y+2+random()*8))
                line([NSPoint(x:x,y:y),end],color:color(hex,0.12+random()*0.4),width:1+random()*3)
            }
        }
        scribble(NSRect(x:0,y:0,width:900,height:610),hex:0xCABC9E,count:10000)
        let window=NSRect(x:135,y:205,width:570,height:335)
        color(0xC0D5DD).setFill(); NSBezierPath(roundedRect:window,xRadius:15,yRadius:15).fill()
        scribble(window.insetBy(dx:5,dy:5),hex:0x82B1C4,count:7000)
        for _ in 0..<65 {
            let x=155+random()*530,y=225+random()*285
            line([NSPoint(x:x,y:y),NSPoint(x:x-9,y:y-22)],color:color(0xE9F0EB,0.8),width:2+random()*2)
        }
        for i in 0..<3 {
            let offset=CGFloat(i)*1.4
            line([NSPoint(x:136+offset,y:205),NSPoint(x:134,y:537+offset),NSPoint(x:702+offset,y:540),NSPoint(x:706,y:207),NSPoint(x:136+offset,y:205)],color:color(0x33332D,0.8),width:3)
            line([NSPoint(x:419+offset,y:207),NSPoint(x:422,y:538)],color:color(0x33332D,0.8),width:3)
            line([NSPoint(x:137,y:365+offset),NSPoint(x:703,y:363)],color:color(0x33332D,0.8),width:3)
        }
        // A quiet windowsill, two mismatched cups, a tiny plant. No faces.
        line([NSPoint(x:92,y:197),NSPoint(x:751,y:195)],color:color(0x38362F),width:6)
        color(0xD7B69C).setFill();NSRect(x:0,y:0,width:900,height:124).fill()
        scribble(NSRect(x:0,y:0,width:900,height:124),hex:0xAD8871,count:4500)
        line([NSPoint(x:0,y:125),NSPoint(x:450,y:128),NSPoint(x:900,y:123)],color:color(0x37342D),width:4)
        func cup(x:CGFloat,y:CGFloat,w:CGFloat,h:CGFloat,hex:UInt32) {
            let r=NSRect(x:x,y:y,width:w,height:h)
            let p=NSBezierPath(roundedRect:r,xRadius:12,yRadius:12);color(hex).setFill();p.fill()
            NSGraphicsContext.saveGraphicsState();p.addClip();scribble(r,hex:0xA48F70,count:1000);NSGraphicsContext.restoreGraphicsState()
            color(0x35332C).setStroke();p.lineWidth=4;p.stroke()
            let handle=NSBezierPath(ovalIn:NSRect(x:x+w-1,y:y+h*0.35,width:28,height:35));handle.lineWidth=4;handle.stroke()
            line([NSPoint(x:x+14,y:y+h),NSPoint(x:x+w-10,y:y+h-1)],color:color(0x35332C),width:4)
            line([NSPoint(x:x+w*0.5,y:y+h+18),NSPoint(x:x+w*0.4,y:y+h+32),NSPoint(x:x+w*0.5,y:y+h+46)],color:color(0x8B887A,0.65),width:3)
        }
        cup(x:245,y:92,w:88,h:94,hex:0xE5C07C)
        cup(x:390,y:84,w:78,h:82,hex:0xC8B8D7)
        let pot=NSBezierPath();pot.move(to:NSPoint(x:655,y:197));pot.line(to:NSPoint(x:674,y:150));pot.line(to:NSPoint(x:721,y:150));pot.line(to:NSPoint(x:737,y:197));pot.close()
        color(0xD5AA99).setFill();pot.fill();pot.lineWidth=4;color(0x39362E).setStroke();pot.stroke()
        line([NSPoint(x:698,y:196),NSPoint(x:698,y:295)],color:color(0x414B36),width:4)
        for (x,y,tilt) in [(673.0,250.0,-30.0),(710,273,25),(678,292,-20)] {
            NSGraphicsContext.saveGraphicsState();let t=NSAffineTransform();t.translateX(by:x,yBy:y);t.rotate(byDegrees:tilt);t.concat()
            let leaf=NSBezierPath(ovalIn:NSRect(x:-9,y:-5,width:36,height:17));color(0x99AD82).setFill();leaf.fill();color(0x3F4936).setStroke();leaf.lineWidth=2.5;leaf.stroke();NSGraphicsContext.restoreGraphicsState()
        }
        texture?.draw(in:NSRect(origin:.zero,size:size),from:.zero,operation:.multiply,fraction:0.38)
        image.unlockFocus()
        return image
    }()
}

// Track the entire video rectangle, independently of transient overlay children.
private struct VideoHoverRegion: NSViewRepresentable {
    let changed: (Bool) -> Void
    func makeNSView(context: Context) -> VideoHoverView { VideoHoverView(changed: changed) }
    func updateNSView(_ view: VideoHoverView, context: Context) { view.changed = changed }
}

private final class VideoHoverView: NSView {
    var changed: (Bool) -> Void
    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func mouseEntered(with event: NSEvent) { changed(true) }
    override func mouseExited(with event: NSEvent) {
        guard let window else { changed(false); return }
        changed(bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)))
    }
}
