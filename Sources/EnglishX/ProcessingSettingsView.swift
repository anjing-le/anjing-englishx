import AppKit
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class EnglishXRoute: ObservableObject {
    @Published var settingsVisible = false
}

struct SelectedVideo {
    let url: URL
    let seconds: Double
    let audioTracks: Int
    let subtitleTracks: Int
}

@MainActor
final class ProcessingSettingsModel: ObservableObject {
    let rules = ProcessingRulesPresentation()
    @Published var connectionStatus = "尚未检查连接"
    @Published var checkingConnection = false
    @Published var report: CodexConnectionReport?
    @Published var connectionFailed = false
    @Published var video: SelectedVideo?
    @Published var thumbnail: NSImage?
    @Published var videoStatus = "选择想练习的视频，先检查时长和音轨。"
    @Published var inspectingVideo = false
    @Published var videoFailed = false
    @Published var processing = false
    @Published var processingStatus = ""
    @Published var processingFailed = false
    @Published var completedPackage: String?
    @Published var workHint = ""
    @Published var review: ClipReviewModel?
    @Published var reviewVisible = false
    var onImported: ((String) -> Void)?
    private var jobProcess: Process?
    func startProcessing(effort: String) {
        guard !processing, review?.saving != true, let video, video.audioTracks > 0 else { return }
        guard let codex = CodexConnectionProbe.executable(),
              let worker = PaperResources.resources.url(forResource: "ingest", withExtension: "py") else {
            processingFailed = true; processingStatus = "找不到本机 Codex 或加工程序。"; return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", worker.path, "--source", video.url.path, "--library", ClipLibrary.directory.path,
                             "--model", ClipLibrary.modelURL.path, "--codex", codex, "--effort", effort,
                             "--work", String(workHint.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        jobProcess = process; processing = true; processingFailed = false; completedPackage = nil
        processingStatus = "正在准备加工…"
        Task {
            defer { processing = false; jobProcess = nil }
            do {
                try await ProcessingJobRunner.run(process: process) { [weak self] event in
                    guard let self else { return }
                    self.processingStatus = event.message ?? self.processingStatus
                    if event.stage == "failed" { self.processingFailed = true }
                    if event.stage == "completed", let file = event.package,
                       let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
                       let package = try? JSONDecoder().decode(ClipPackage.self, from: data), package.validated() {
                        self.completedPackage = file
                        self.onImported?(package.id)
                    }
                }
                if completedPackage == nil && !processingFailed {
                    processingFailed = true; processingStatus = "任务结束但没有通过校验的片段，未加入学习库。"
                }
            } catch {
                if !processingFailed && completedPackage == nil {
                    processingFailed = true; processingStatus = "加工已停止或失败，已有片段保持不变。"
                }
            }
        }
    }
    func cancelProcessing() {
        if jobProcess?.isRunning == true { jobProcess?.terminate() }
        review?.cancel()
    }
    func openReview(_ path: String) {
        guard !processing, review?.saving != true else { return }
        rules.close()
        if review?.packageURL.path == path { reviewVisible = true; return }
        do {
            review?.close()
            review = try ClipReviewModel(packageURL: URL(fileURLWithPath: path)); reviewVisible = true
        } catch { processingFailed = true; processingStatus = "无法打开这个片段的校对资料。" }
    }
    func checkConnection() {
        guard !checkingConnection else { return }
        checkingConnection = true; connectionFailed = false
        connectionStatus = "正在检查本机登录和模型目录…"
        Task {
            defer { checkingConnection = false }
            do {
                let report = try await CodexConnectionProbe.check()
                self.report = report
                connectionStatus = "已连接本机 Codex，模型目录包含 gpt-6.1-sol。尚未发送生成任务。"
            } catch {
                report = nil; connectionFailed = true
                connectionStatus = (error as? CodexProbeError)?.errorDescription ?? "连接检查失败，请重试。"
            }
        }
    }
    func chooseVideo() {
        guard !processing, !inspectingVideo else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.prompt = "选择视频"
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0 is PaperWindow && $0.isVisible }) else { return }
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.inspect(url) }
        }
    }
    func acceptDrop(_ providers: [NSItemProvider], accepted: @escaping () -> Void = {}) -> Bool {
        guard !processing, !inspectingVideo else { return false }
        guard providers.count == 1, let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            videoFailed = true; videoStatus = "请一次拖入一个本地视频。"; return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] value, _ in
            let url: URL?
            if let file = value as? URL { url = file }
            else if let data = value as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
            else { url = nil }
            Task { @MainActor in
                guard let self else { return }
                guard let url, url.isFileURL else {
                    self.videoFailed = true; self.videoStatus = "暂时无法读取拖入的文件。"; return
                }
                accepted(); self.inspect(url)
            }
        }
        return true
    }
    private func inspect(_ url: URL) {
        guard !processing, !inspectingVideo else { return }
        inspectingVideo = true; videoFailed = false; video = nil; thumbnail = nil
        workHint = ""
        processingStatus = ""; completedPackage = nil
        videoStatus = "正在读取视频信息…"
        Task {
            defer { inspectingVideo = false }
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { videoFailed = true; videoStatus = "请选择一个视频文件。"; return }
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                let videos = try await asset.loadTracks(withMediaType: .video)
                let audio = try await asset.loadTracks(withMediaType: .audio)
                let subtitles = try await asset.loadTracks(withMediaType: .subtitle)
                guard seconds.isFinite, seconds > 0, !videos.isEmpty else {
                    videoFailed = true; videoStatus = "这个文件没有可用的视频轨道或时长。"; return
                }
                video = SelectedVideo(url: url, seconds: seconds, audioTracks: audio.count, subtitleTracks: subtitles.count)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 520, height: 320)
                if let frame = try? await generator.image(at: CMTime(seconds: min(1, seconds / 2), preferredTimescale: 600)) {
                    thumbnail = NSImage(cgImage: frame.image, size: .zero)
                }
                videoFailed = audio.isEmpty
                videoStatus = audio.isEmpty ? "未找到音轨，不能识别对白。" : "视频已选择，尚未开始加工。原文件保持不变。"
            } catch {
                videoFailed = true; videoStatus = "暂时无法读取这个视频，请检查文件格式和访问权限。"
            }
        }
    }
}

struct EnglishXRootView: View {
    @ObservedObject var route: EnglishXRoute
    @ObservedObject var learning: LearningMockModel
    @ObservedObject var processing: ProcessingSettingsModel
    @ObservedObject var menus: PaperMenus
    var body: some View {
        ZStack {
            LearningMockView(model: learning, importVideo: { providers in
                processing.acceptDrop(providers) {
                    learning.isPlaying = false
                    menus.close()
                    route.settingsVisible = true
                }
            }, acceptingVideo: !processing.processing && !processing.inspectingVideo)
                .opacity(route.settingsVisible ? 0 : 1)
                .allowsHitTesting(!route.settingsVisible)
                .accessibilityHidden(route.settingsVisible)
            if route.settingsVisible {
                ProcessingSettingsView(model: processing,
                    studyPackage: learning.clip.mediaURL?.deletingLastPathComponent().appendingPathComponent("clip.json").path) {
                    route.settingsVisible = false
                }
            }
        }
        .environmentObject(menus)
        .overlayPreferenceValue(PaperMenuAnchors.self) { anchors in PaperMenuLayer(menus: menus, anchors: anchors) }
        .onChange(of: menus.isOpen) { _, open in
            learning.menuTracking = open
            if !open { learning.revealControls(for: 0.6) }
        }
        .onChange(of: route.settingsVisible) { _, _ in menus.close() }
    }
}

struct ProcessingSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: ProcessingSettingsModel
    let studyPackage: String?
    let back: () -> Void
    @AppStorage("processing.effort") private var effort = "low"
    var body: some View {
        Group {
            if model.reviewVisible, let review = model.review {
                ClipReviewView(model: review, effort: effort, back: {
                    guard !review.saving else { return }
                    review.stopPreview(); model.reviewVisible = false
                }, completed: { file, id in
                    review.close(); model.review = nil; model.reviewVisible = false
                    model.completedPackage = file; model.processingFailed = false
                    model.processingStatus = "校对已保存，分析已更新。"
                    model.onImported?(id)
                })
            } else { settingsContent }
        }
    }
    private var settingsContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 38) {
                    HStack(spacing: 16) {
                        Button(action: back) { Image(systemName: "arrow.left") }
                            .buttonStyle(PaintedButtonStyle(color: Palette.sage)).accessibilityLabel("返回学习")
                        Text("设置").font(Palette.handwriting(30))
                    }
                    if geometry.size.width >= 780 {
                        HStack(alignment: .top, spacing: 0) {
                            modelSection.frame(width: 240, alignment: .leading).padding(.trailing, 30)
                            SettingsPencilDivider()
                                .stroke(Palette.ink.opacity(0.23), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                                .frame(width: 6, height: max(330, geometry.size.height - 195))
                                .padding(.vertical, 18).padding(.trailing, 34)
                                .accessibilityHidden(true)
                            videoSection.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 30) {
                            modelSection
                            RoundedRectangle(cornerRadius: 1).fill(Palette.ink.opacity(0.18))
                                .frame(height: 1).padding(.horizontal, 12).padding(.vertical, 2)
                            videoSection
                        }
                    }
                }
                .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, geometry.size.width >= 780 ? 48 : 30)
                .padding(.top, 46).padding(.bottom, 40)
                .background { QuietScrollChrome() }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Palette.ink)
        .overlayPreferenceValue(ProcessingRulesAnchor.self) { anchor in
            ProcessingRulesLayer(presentation: model.rules, anchor: anchor, effort: effort,
                completedPackage: model.completedPackage ?? studyPackage,
                recipeTitle: model.completedPackage == nil ? "当前学习片段使用" : "这份结果使用")
        }
        .onDisappear { model.rules.close() }
    }
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("模型").font(Palette.handwriting(23))
            Text("gpt-6.1-sol").font(.custom("AvenirNext-Medium", size: 21))
            HStack(spacing: 12) {
                if let report = model.report, !report.efforts.isEmpty {
                    PaperChoice(title: "推理强度", value: effort,
                                options: report.efforts.map { PaperOption(value: $0, label: $0) }) { effort = $0 }
                } else {
                    Text(effort).font(.system(size: 13)).foregroundStyle(Palette.muted)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Palette.sage.opacity(0.16), in: Capsule())
                }
                Button(model.checkingConnection ? "连接中…" : (model.report == nil ? "连接" : "已连接")) { model.checkConnection() }
                    .buttonStyle(PaintedButtonStyle(color: model.report == nil ? Palette.yellow : Palette.sage))
                    .disabled(model.checkingConnection)
            }
            if model.connectionFailed {
                Text(model.connectionStatus).font(.system(size: 12)).foregroundStyle(Palette.spoken)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: model.report?.efforts) { _, efforts in
            if let efforts, !efforts.contains(effort), let suggested = model.report?.defaultEffort { effort = suggested }
        }
    }
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("视频").font(Palette.handwriting(23))
                Spacer()
                ProcessingRulesBadge(presentation: model.rules)
            }
            VideoImportZone(model: model)
            if model.video != nil {
                TextField("作品名（选填）", text: $model.workHint)
                    .textFieldStyle(.plain).font(.system(size: 14)).tint(Palette.ink)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(Palette.paper.opacity(model.workHint.isEmpty ? 0 : 0.8), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.7), lineWidth: 0.8))
                    .shadow(color: Palette.ink.opacity(0.04), radius: 6, y: 2)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: model.workHint.isEmpty)
                    .disabled(model.processing)
                    .accessibilityLabel("作品名，可选，帮助识别剧中角色")
            }
            if model.videoFailed {
                Text(model.videoStatus).font(.system(size: 12)).foregroundStyle(Palette.spoken)
            }
            HStack(spacing: 15) {
                if model.processing {
                    Button("停止加工") { model.cancelProcessing() }.buttonStyle(PaintedButtonStyle(color: Palette.peach))
                } else {
                    Button("开始加工") { model.startProcessing(effort: effort) }.buttonStyle(PaintedButtonStyle(color: Palette.yellow))
                        .disabled(model.video == nil || model.videoFailed || model.inspectingVideo)
                }
                if model.completedPackage != nil {
                    Button("查看片段") { back() }.buttonStyle(PaintedButtonStyle(color: Palette.sage))
                }
                if let path = model.completedPackage ?? studyPackage {
                    Button(model.review?.changed == true ? "继续校对" : "校对片段") { model.openReview(path) }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted)
                        .accessibilityLabel(model.review?.changed == true ? "继续校对当前学习片段" : "校对当前学习片段")
                        .disabled(model.processing)
                }
                Spacer(minLength: 0)
            }
            if !model.processingStatus.isEmpty && (model.processing || model.processingFailed || model.completedPackage == nil) {
                Text(model.processingStatus).font(.system(size: 12))
                    .foregroundStyle(model.processingFailed ? Palette.spoken : Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.completedPackage != nil {
                Text("待核对").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct SettingsPencilDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 0.4, y: 0))
        path.addCurve(to: CGPoint(x: rect.midX + 0.4, y: rect.height),
                      control1: CGPoint(x: rect.midX + 0.7, y: rect.height * 0.34),
                      control2: CGPoint(x: rect.midX - 0.7, y: rect.height * 0.7))
        return path
    }
}
