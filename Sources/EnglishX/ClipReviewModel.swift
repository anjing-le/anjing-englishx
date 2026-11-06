import AVFoundation
import CryptoKit
import SwiftUI

struct ReviewWord: Identifiable, Equatable {
    let id: String
    var text: String
    var start: String
    var end: String
}
struct ReviewLine: Identifiable, Equatable {
    let id: UUID
    var text: String
    var speakerName: String
    var speakerConfirmed: Bool
    var words: [ReviewWord]
    var sourceSegmentIDs: [Int]
}

@MainActor
final class ClipReviewModel: ObservableObject {
    let packageURL: URL
    let package: ClipPackage
    let baseHash: String
    let player: AVPlayer
    @Published var lines: [ReviewLine]
    @Published var selected = 0 { didSet { stopPreview(); showSelectedFrame() } }
    @Published var saving = false
    @Published var status = ""
    @Published var failed = false
    @Published var playing = false
    private let initialLines: [ReviewLine]
    private var process: Process?
    private var observer: Any?
    private var stopAt: Double?
    private var previewID = UUID()

    init(packageURL: URL) throws {
        let data = try Data(contentsOf: packageURL)
        let package = try JSONDecoder().decode(ClipPackage.self, from: data)
        guard package.validated() else { throw CodexProbeError.invalid }
        self.packageURL = packageURL; self.package = package
        baseHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let lines = package.segments.map { segment in
            ReviewLine(id: UUID(), text: segment.text, speakerName: segment.speaker == "未标注" ? "" : segment.speaker,
                speakerConfirmed: segment.characterAssignment?.confidence == "manual",
                words: segment.words.map { ReviewWord(id: $0.id, text: $0.text, start: Self.seconds($0.start), end: Self.seconds($0.end)) },
                sourceSegmentIDs: [segment.id])
        }
        self.lines = lines; initialLines = lines
        player = AVPlayer(url: packageURL.deletingLastPathComponent().appendingPathComponent(package.media))
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.03, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, let stopAt = self.stopAt else { return }
                // Use current player time: an older callback may arrive just after a new seek.
                if self.player.currentTime().seconds >= stopAt { self.stopPreview() }
            }
        }
        showSelectedFrame()
    }
    var changed: Bool { lines != initialLines }
    func resetDraft() {
        guard !saving else { return }
        stopPreview(); lines = initialLines; selected = min(selected, lines.count - 1); status = ""; failed = false
    }
    private func showSelectedFrame() {
        guard lines.indices.contains(selected), let first = lines[selected].words.first, let start = Double(first.start) else { return }
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    static func seconds(_ value: Double) -> String { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value) }
    var validation: String? {
        var end = 0.0
        for (i, line) in lines.enumerated() {
            if line.text.split(whereSeparator: \.isWhitespace).map(String.init) != line.words.map(\.text) {
                return "第 \(i + 1) 句的原话有更改，请先更新词表。"
            }
            if line.words.isEmpty { return "第 \(i + 1) 句至少需要一个词。" }
            if line.speakerName.count > 80 || line.speakerName.contains("\n") { return "第 \(i + 1) 句的角色名过长或包含换行。" }
            for (j, word) in line.words.enumerated() {
                guard let start = Double(word.start), let finish = Double(word.end), start.isFinite, finish.isFinite,
                      start >= end - 0.0001, start >= 0, finish > start, finish <= package.duration else {
                    return "请检查第 \(i + 1) 句第 \(j + 1) 个词的起止时间，不能重叠或超出视频。"
                }
                end = finish
            }
        }
        return nil
    }
    func syncWords() {
        guard !saving, lines.indices.contains(selected) else { return }
        let tokens = lines[selected].text.split(whereSeparator: \.isWhitespace).map(String.init)
        let old = lines[selected].words
        if tokens.count == old.count {
            lines[selected].words = zip(tokens, old).map { token, word in
                var changed = word; changed.text = token; return changed
            }
        } else {
            var prefix = 0, suffix = 0
            while prefix < min(tokens.count, old.count), tokens[prefix] == old[prefix].text { prefix += 1 }
            while suffix < min(tokens.count, old.count) - prefix,
                  tokens[tokens.count - suffix - 1] == old[old.count - suffix - 1].text { suffix += 1 }
            lines[selected].words = tokens.enumerated().map { i, token in
                if i < prefix { return old[i] }
                if i >= tokens.count - suffix { return old[old.count - (tokens.count - i)] }
                return ReviewWord(id: "review-" + UUID().uuidString, text: token, start: "", end: "")
            }
        }
        lines[selected].text = tokens.joined(separator: " ")
        status = tokens.count == old.count ? "词表已更新，请听回确认时间。" : "新增或替换的词需要填写起止秒数。"
        failed = false
    }
    func split(after wordID: String) {
        guard !saving, let position = lines[selected].words.firstIndex(where: { $0.id == wordID }),
              position < lines[selected].words.count - 1 else { return }
        stopPreview()
        let original = lines[selected]
        let head = Array(original.words[...position]), tail = Array(original.words[(position + 1)...])
        lines[selected].words = head; lines[selected].text = head.map(\.text).joined(separator: " ")
        let next = ReviewLine(id: UUID(), text: tail.map(\.text).joined(separator: " "), speakerName: "",
            speakerConfirmed: false, words: tail, sourceSegmentIDs: original.sourceSegmentIDs)
        lines.insert(next, at: selected + 1)
        status = "已拆成两句，下一句的说话人会重新分析，也可以手动确认。"; failed = false
    }
    func mergeNext() {
        guard !saving, lines.indices.contains(selected + 1) else { return }
        stopPreview()
        let next = lines[selected + 1]
        if next.speakerName != lines[selected].speakerName || !next.speakerConfirmed {
            lines[selected].speakerName = ""; lines[selected].speakerConfirmed = false
        }
        lines[selected].words += next.words
        lines[selected].text = lines[selected].words.map(\.text).joined(separator: " ")
        lines[selected].sourceSegmentIDs += next.sourceSegmentIDs
        lines.remove(at: selected + 1); status = "已合并，请核对说话人。"; failed = false
    }
    func preview(from start: Double? = nil, to end: Double? = nil) {
        guard let first = lines[selected].words.first, let last = lines[selected].words.last,
              let beginning = start ?? Double(first.start), let finish = end ?? Double(last.end),
              beginning.isFinite, finish.isFinite, beginning >= 0, finish > beginning, finish <= package.duration else { return }
        stopPreview(); let identifier = UUID(); previewID = identifier
        player.seek(to: CMTime(seconds: beginning, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.previewID == identifier else { return }
                self.stopAt = finish; self.playing = true; self.player.play()
            }
        }
    }
    func stopPreview() { previewID = UUID(); player.pause(); playing = false; stopAt = nil }
    func close() {
        stopPreview(); cancel()
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
    }
    func cancel() { if process?.isRunning == true { process?.terminate() } }
    func requestData() throws -> Data {
        if let validation { throw NSError(domain: "Review", code: 1, userInfo: [NSLocalizedDescriptionKey: validation]) }
        let rows: [[String: Any]] = lines.map { line in
            ["speakerName":line.speakerName.trimmingCharacters(in: .whitespacesAndNewlines), "speakerConfirmed":line.speakerConfirmed,
             "sourceSegmentIDs":line.sourceSegmentIDs,
             "words":line.words.map { ["id":$0.id,"text":$0.text,"start":Double($0.start)!,"end":Double($0.end)!] as [String: Any] }]
        }
        return try JSONSerialization.data(withJSONObject: ["schemaVersion":1,"baseSHA256":baseHash,"segments":rows], options: [.sortedKeys])
    }
    func save(effort: String, completed: @escaping (String, String) -> Void) {
        guard !saving, changed, validation == nil else { return }
        stopPreview()
        do {
            guard let codex = CodexConnectionProbe.executable(),
                  let worker = PaperResources.resources.url(forResource: "review", withExtension: "py") else { throw CodexProbeError.invalid }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("EnglishXReview/" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let edits = folder.appendingPathComponent("corrections.json")
            try requestData().write(to: edits, options: .atomic)
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-u",worker.path,"--package",packageURL.path,"--corrections",edits.path,
                                 "--library",ClipLibrary.directory.path,"--codex",codex,"--effort",effort]
            process.currentDirectoryURL = folder; self.process = process
            saving = true; failed = false; status = "正在按校对内容更新分析…"
            Task {
                defer { saving = false; self.process = nil }
                var result: (String, String)?
                do {
                    try await ProcessingJobRunner.run(process: process) { [weak self] event in
                        guard let self else { return }
                        self.status = event.message ?? self.status
                        if event.stage == "failed" { self.failed = true }
                        if event.stage == "completed", let path = event.package,
                           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                           let package = try? JSONDecoder().decode(ClipPackage.self, from: data), package.validated() {
                            result = (path, package.id)
                        }
                    }
                    if let result { completed(result.0, result.1) }
                    else { failed = true; status = "校对结果未通过校验，原片段保持不变。" }
                } catch {
                    if !failed { failed = true; status = "加工已停止或失败，原片段保持不变。" }
                }
            }
        } catch { failed = true; status = "无法开始校对加工，请检查输入和本机 Codex。" }
    }
}
