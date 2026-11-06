import XCTest
@testable import EnglishX

final class CharacterTests: XCTestCase {
    private func fixture(confidence: String = "high", frameIDs: [String] = ["f0", "f1"], speakerID: String = "c1", manualRevision: Bool = false) throws -> ClipPackage {
        var assignment: [String: Any] = ["segmentID":0, "characterID":"c1", "confidence":confidence, "evidence":"fixture evidence", "frameIDs":frameIDs]
        if manualRevision { assignment["reviewSource"] = "user" }
        var data: [String: Any] = ["schemaVersion":1,"id":"abcdef1234","name":"fixture","media":"media.mp4","reviewStatus":"needs-review","duration":1.0,
            "characterAnalysis":["characters":[["id":"c1","name":"Saul Goodman","work":"fictional fixture","evidence":"fixture"]],"assignments":[assignment]],
            "characterFrames":[["id":"f0","segmentID":0,"time":0.3],["id":"f1","segmentID":0,"time":0.6]],
            "segments":[["id":0,"speaker":"Saul Goodman","speakerID":speakerID,"characterAssignment":assignment,"text":"Hello.","start":0.0,"end":1.0,
                         "words":[["id":"s0-w0","text":"Hello.","start":0.2,"end":0.8,
                                   "analysis":["id":"s0-w0","lemma":"hello","partOfSpeech":"感叹词","meaningZh":"你好","explanationZh":"用来打招呼。","phrase":""]]]]]]
        if manualRevision { data["revisionSource"] = "manual-editor-v1" }
        return try JSONDecoder().decode(ClipPackage.self, from: JSONSerialization.data(withJSONObject: data))
    }
    func testNamedSuggestionNeedsValidEvidenceAndIdentity() throws {
        XCTAssertTrue(try fixture().validated())
        XCTAssertFalse(try fixture(frameIDs: ["f0"]).validated())
        XCTAssertFalse(try fixture(frameIDs: ["f0", "other-segment"]).validated())
        XCTAssertFalse(try fixture(speakerID: "other-character").validated())
        XCTAssertFalse(try fixture(confidence: "uncertain").validated())
    }
    func testConsecutiveLinesFromSameCharacterKeepSameSide() {
        let speakers = ["Saul", "Saul", "Kim", "Saul", "Kim"]
        let lines = speakers.enumerated().map { i, name in
            DialogueLine(id: i, start: Double(i), end: Double(i + 1), speaker: name, text: "Hi", words: [], speakerID: name)
        }
        let clip = StudyClip(id: 100, name: "fixture", subtitle: "", duration: 5, tint: Palette.blue, lines: lines)
        XCTAssertEqual(lines.map { clip.isTrailing($0) }, [false, false, true, false, true])
    }
    func testManualAssignmentRequiresExplicitRevisionProvenance() throws {
        XCTAssertFalse(try fixture(confidence: "manual", frameIDs: []).validated())
        XCTAssertTrue(try fixture(confidence: "manual", frameIDs: [], manualRevision: true).validated())
        XCTAssertFalse(try fixture(confidence: "manual", frameIDs: [], speakerID: "wrong", manualRevision: true).validated())
    }
}
