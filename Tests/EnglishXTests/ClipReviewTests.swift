import XCTest
@testable import EnglishX

final class ClipReviewTests: XCTestCase {
    @MainActor private func fixture() throws -> ClipReviewModel {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("review-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let words: [[String: Any]] = ["Hello", "there."].enumerated().map { i, text in
            ["id":"s0-w\(i)","text":text,"start":Double(i) * 0.5,"end":Double(i + 1) * 0.5,
             "analysis":["id":"s0-w\(i)","lemma":text,"partOfSpeech":"fixture","meaningZh":"旧释义","explanationZh":"旧讲解","phrase":""]]
        }
        let document: [String: Any] = ["schemaVersion":1,"id":"abcdef1234","name":"fixture","media":"media.mp4","reviewStatus":"needs-review","duration":1.0,
            "segments":[["id":0,"speaker":"未标注","text":"Hello there.","start":0,"end":1,"words":words]]]
        let url = folder.appendingPathComponent("clip.json")
        try JSONSerialization.data(withJSONObject: document).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try ClipReviewModel(packageURL: url)
    }
    @MainActor func testChangedTextDoesNotSubmitOldTeachingAnalysis() throws {
        let model = try fixture(); defer { model.close() }
        XCTAssertFalse(model.changed)
        model.lines[0].text = "Welcome there."
        XCTAssertNotNil(model.validation)
        model.syncWords()
        XCTAssertNil(model.validation)
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: model.requestData()) as? [String: Any])
        let rows = try XCTUnwrap(request["segments"] as? [[String: Any]])
        let words = try XCTUnwrap(rows[0]["words"] as? [[String: Any]])
        XCTAssertEqual(words[0]["text"] as? String, "Welcome")
        XCTAssertNil(words[0]["analysis"])
        XCTAssertEqual(words[0]["id"] as? String, "s0-w0")
    }
    @MainActor func testInsertedWordsRequireExplicitTimesInsteadOfProportionalGuessing() throws {
        let model = try fixture(); defer { model.close() }
        model.lines[0].text = "Hello kind friend."
        model.syncWords()
        XCTAssertEqual(model.lines[0].words[0].start, "0.0000")
        XCTAssertEqual(model.lines[0].words[1].start, "")
        XCTAssertThrowsError(try model.requestData())
        model.lines[0].words[1].start = "0.5"; model.lines[0].words[1].end = "0.75"
        model.lines[0].words[2].start = "0.75"; model.lines[0].words[2].end = "1"
        XCTAssertNil(model.validation)
        model.lines[0].words[2].start = "0.7"
        XCTAssertNotNil(model.validation)
    }
    @MainActor func testSplitKeepsWordTimesAndDoesNotAssignSecondSpeaker() throws {
        let model = try fixture(); defer { model.close() }
        let oldWords = model.lines[0].words
        model.lines[0].speakerName = "A"; model.lines[0].speakerConfirmed = true
        model.split(after: oldWords[0].id)
        XCTAssertEqual(model.lines.count, 2)
        XCTAssertEqual(model.lines.flatMap(\.words), oldWords)
        XCTAssertEqual(model.lines[1].speakerName, "")
        XCTAssertFalse(model.lines[1].speakerConfirmed)
        XCTAssertNil(model.validation)
        model.mergeNext()
        XCTAssertEqual(model.lines[0].words, oldWords)
        XCTAssertFalse(model.lines[0].speakerConfirmed)
    }
}
