import Foundation
import AVFoundation
import SwiftUI

struct ClipPackage: Decodable {
    struct Analysis: Decodable {
        let id: String, lemma: String, partOfSpeech: String, meaningZh: String, explanationZh: String, phrase: String
    }
    struct Word: Decodable { let id: String, text: String; let start: Double, end: Double; let analysis: Analysis }
    struct Character: Decodable { let id: String, name: String, work: String, evidence: String }
    struct CharacterAssignment: Decodable, Equatable {
        let segmentID: Int, characterID: String, confidence: String, evidence: String
        let frameIDs: [String]
        let reviewSource: String?
    }
    struct CharacterAnalysis: Decodable { let characters: [Character]; let assignments: [CharacterAssignment] }
    struct CharacterFrame: Decodable { let id: String; let segmentID: Int; let time: Double }
    struct Segment: Decodable {
        let id: Int, speaker: String, text: String
        let start: Double, end: Double
        let words: [Word]
        let speakerID: String?
        let characterAssignment: CharacterAssignment?
    }
    struct Attribution: Decodable { let title: String, author: String, credit: String, source: String, license: String, licenseURL: String, modification: String }
    let schemaVersion: Int
    let id: String, name: String, media: String, reviewStatus: String
    let duration: Double
    let sourceSHA256: String?
    let segments: [Segment]
    let attribution: Attribution?
    let characterAnalysis: CharacterAnalysis?
    let characterFrames: [CharacterFrame]?
    let revisionSource: String?

    func validated() -> Bool {
        guard schemaVersion == 1, duration.isFinite, duration > 0, !segments.isEmpty,
              media == "media.mp4", !id.isEmpty else { return false }
        var ids = Set<String>(), previousStart = -Double.infinity
        for (index, segment) in segments.enumerated() {
            guard segment.id == index, !segment.words.isEmpty, segment.start.isFinite, segment.end.isFinite,
                  segment.start >= 0, segment.end > segment.start, segment.end <= duration + 0.02,
                  segment.start >= previousStart,
                  segment.text == segment.words.map(\.text).joined(separator: " ") else { return false }
            previousStart = segment.start
            var previousEnd = segment.start
            for word in segment.words {
                guard ids.insert(word.id).inserted, word.analysis.id == word.id, !word.text.isEmpty,
                      word.start.isFinite, word.end.isFinite, word.start >= previousEnd - 0.0001,
                      word.end > word.start, word.end <= segment.end + 0.0001,
                      !word.analysis.partOfSpeech.isEmpty, !word.analysis.meaningZh.isEmpty,
                      !word.analysis.explanationZh.isEmpty else { return false }
                previousEnd = word.end
            }
        }
        return validCharacters()
    }
    private func validCharacters() -> Bool {
        guard let analysis = characterAnalysis else {
            return characterFrames == nil && segments.allSatisfy { $0.speakerID == nil && $0.characterAssignment == nil }
        }
        guard let frames = characterFrames,
              Set(analysis.characters.map(\.id)).count == analysis.characters.count,
              Set(analysis.assignments.map(\.segmentID)) == Set(segments.map(\.id)),
              analysis.assignments.count == segments.count,
              Set(frames.map(\.id)).count == frames.count else { return false }
        for character in analysis.characters {
            guard !character.id.isEmpty, !character.name.isEmpty, !character.work.isEmpty, !character.evidence.isEmpty else { return false }
        }
        for frame in frames {
            guard segments.indices.contains(frame.segmentID), frame.time.isFinite, !frame.id.isEmpty,
                  frame.time >= segments[frame.segmentID].start, frame.time <= segments[frame.segmentID].end else { return false }
        }
        for segment in segments {
            guard let a = segment.characterAssignment,
                  analysis.assignments.first(where: { $0.segmentID == segment.id }) == a,
                  ["high", "manual", "uncertain", "unknown"].contains(a.confidence), !a.evidence.isEmpty,
                  a.characterID.isEmpty || analysis.characters.contains(where: { $0.id == a.characterID }),
                  a.frameIDs.allSatisfy({ id in frames.contains { $0.id == id && $0.segmentID == segment.id } }) else { return false }
            if a.confidence == "high" || a.confidence == "manual" {
                if a.confidence == "high", Set(a.frameIDs).count < 2 { return false }
                if a.confidence == "manual", revisionSource != "manual-editor-v1" || a.reviewSource != "user" { return false }
                guard let character = analysis.characters.first(where: { $0.id == a.characterID }),
                      segment.speakerID == character.id, segment.speaker == character.name else { return false }
            } else if segment.speakerID != nil || segment.speaker != "未标注" { return false }
        }
        return true
    }
}

@MainActor
enum ClipLibrary {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EnglishX/Library", isDirectory: true)
    }
    static var modelURL: URL { directory.deletingLastPathComponent().appendingPathComponent("Models/ggml-base.en.bin") }
    static func load() -> [StudyClip] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        var seenSources = Set<String>()
        return folders.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("clip.json")),
                  let package = try? JSONDecoder().decode(ClipPackage.self, from: data), package.validated(),
                  FileManager.default.fileExists(atPath: folder.appendingPathComponent(package.media).path) else { return nil }
            if let source = package.sourceSHA256, !seenSources.insert(source).inserted { return nil }
            let lines = package.segments.map { segment in
                DialogueLine(id: segment.id, start: segment.start, end: segment.end, speaker: segment.speaker, text: segment.text,
                    words: segment.words.enumerated().map { index, word in
                        TimedWord(id: index, text: word.text, start: word.start, end: word.end)
                    }, speakerID: segment.speakerID, speakerEvidence: segment.characterAssignment?.evidence,
                    speakerNeedsReview: segment.speakerID != nil && segment.characterAssignment?.confidence != "manual")
            }
            var clip = StudyClip(id: Int(String(package.id.prefix(7)), radix: 16) ?? 100, name: package.name,
                                 subtitle: package.reviewStatus == "needs-review" ? "待核对" : "已核对",
                                 duration: package.duration, tint: Palette.blue, lines: lines)
            clip.mediaURL = folder.appendingPathComponent(package.media)
            clip.notes = package.segments.map { segment in
                segment.words.map { word in
                    let a = word.analysis
                    return WordExplanation(partOfSpeech: a.partOfSpeech, meaning: a.meaningZh,
                        explanation: a.explanationZh, lemma: a.lemma, phrase: a.phrase)
                }
            }
            clip.attribution = package.attribution
            clip.packageID = package.id
            return clip
        }
    }
}

struct LocalVideoView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> VideoLayerView { let view = VideoLayerView(); view.video.player = player; return view }
    func updateNSView(_ view: VideoLayerView, context: Context) { if view.video.player !== player { view.video.player = player } }
    static func dismantleNSView(_ view: VideoLayerView, coordinator: ()) { view.video.player = nil }
}
final class VideoLayerView: NSView {
    let video = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        video.videoGravity = .resizeAspect; layer?.addSublayer(video)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); CATransaction.begin(); CATransaction.setDisableActions(true); video.frame = bounds; CATransaction.commit() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
