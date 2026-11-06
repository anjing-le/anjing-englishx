import XCTest
@testable import EnglishX

final class ClipPackageTests: XCTestCase {
    private func fixture(start: Double = 0.2, end: Double = 0.8, analysisID: String = "s0-w0", media: String = "media.mp4") throws -> ClipPackage {
        let data: [String: Any] = ["schemaVersion":1,"id":"abcdef1234","name":"fixture","media":media,"reviewStatus":"needs-review","duration":1.0,
            "segments":[["id":0,"speaker":"未标注","text":"Hello.","start":0.0,"end":1.0,
                         "words":[["id":"s0-w0","text":"Hello.","start":start,"end":end,
                                   "analysis":["id":analysisID,"lemma":"hello","partOfSpeech":"感叹词","meaningZh":"你好","explanationZh":"用来打招呼。","phrase":""]]]]]]
        return try JSONDecoder().decode(ClipPackage.self, from: JSONSerialization.data(withJSONObject: data))
    }
    func testValidUnreviewedPackageIsLoadable() throws { XCTAssertTrue(try fixture().validated()) }
    func testWrongWordAssociationCannotEnterPlayer() throws { XCTAssertFalse(try fixture(analysisID: "other-word").validated()) }
    func testInvalidTimeCannotEnterPlayer() throws {
        XCTAssertFalse(try fixture(start: -0.1).validated())
        XCTAssertFalse(try fixture(start: 0.8, end: 0.2).validated())
        XCTAssertFalse(try fixture(end: 1.1).validated())
    }
    func testMediaPathCannotEscapePackage() throws { XCTAssertFalse(try fixture(media:"../other.mp4").validated()) }
}
