import XCTest
@testable import EnglishX

final class KaraokeTimingTests: XCTestCase {
    func testWordBoundariesAndPartialFill() {
        let word = TimedWord(id: 0, text: "umbrella?", start: 2, end: 4)
        XCTAssertEqual(word.progress(at: -1), 0)
        XCTAssertEqual(word.progress(at: 2), 0)
        XCTAssertEqual(word.progress(at: 2.5), 0.25)
        XCTAssertEqual(word.progress(at: 3), 0.5)
        XCTAssertEqual(word.progress(at: 4), 1)
        XCTAssertEqual(word.progress(at: 8), 1)
    }

    func testAllMockWordsPreserveTextAndFitTheirLine() async {
        await MainActor.run {
            XCTAssertEqual(MockWordNotes.clips.count, StudyClip.examples.count)
            for (clipIndex, clip) in StudyClip.examples.enumerated() {
                XCTAssertEqual(MockWordNotes.clips[clipIndex].count, clip.lines.count)
                for line in clip.lines {
                    XCTAssertEqual(MockWordNotes.clips[clipIndex][line.id].count, line.words.count)
                    for note in MockWordNotes.clips[clipIndex][line.id] {
                        XCTAssertFalse(note.partOfSpeech.isEmpty)
                        XCTAssertFalse(note.meaning.isEmpty)
                        XCTAssertFalse(note.explanation.isEmpty)
                    }
                    XCTAssertEqual(line.words.map(\.text).joined(separator: " "), line.text)
                    var end = line.start
                    for word in line.words {
                        XCTAssertGreaterThanOrEqual(word.start, end)
                        XCTAssertGreaterThan(word.end, word.start)
                        XCTAssertLessThanOrEqual(word.end, line.end)
                        end = word.end
                    }
                }
            }
        }
    }

    func testPauseSpeedSeekAndRewindUseTheSameTime() async {
        await MainActor.run {
            let model = LearningMockModel(loadLibrary: false)
            model.time = 10.4
            let firstWord = model.clip.lines[2].words[0]
            XCTAssertEqual(firstWord.progress(at: model.time), 0.5, accuracy: 0.00001)
            model.advance(by: 1)
            XCTAssertEqual(model.time, 10.4) // paused: the half-filled word stays still
            model.toggle()
            model.speed = 0.5
            model.advance(by: 1)
            XCTAssertEqual(model.time, 10.9, accuracy: 0.00001)
            let secondWord = model.clip.lines[2].words[1]
            XCTAssertEqual(secondWord.progress(at: model.time), 1.0 / 6, accuracy: 0.00001)
            model.speed = 1.25
            model.advance(by: 0.4)
            XCTAssertEqual(model.time, 11.4, accuracy: 0.00001)
            XCTAssertEqual(secondWord.progress(at: model.time), 1, accuracy: 0.00001)
            model.toggle()
            model.advance(by: 3)
            XCTAssertEqual(model.time, 11.4, accuracy: 0.00001)
            model.jump(-1)
            XCTAssertEqual(firstWord.progress(at: model.time), 0.5, accuracy: 0.00001)
            XCTAssertEqual(secondWord.progress(at: model.time), 0)
            model.jump(7)
            XCTAssertEqual(model.activeID, 3)
            model.time = 11.1 // slider or sentence positioning changes the same source of truth
            XCTAssertEqual(model.activeID, 2)
            XCTAssertEqual(secondWord.progress(at: model.time), 0.5, accuracy: 0.00001)
            model.select(1)
            XCTAssertEqual(model.time, 0)
            XCTAssertFalse(model.isPlaying)
            XCTAssertEqual(model.clip.lines[0].words[0].progress(at: model.time), 0)
        }
    }

    func testEndOfClipStopsAndReplayResetsWordFill() async {
        await MainActor.run {
            let model = LearningMockModel(loadLibrary: false)
            model.time = model.clip.duration - 0.1
            model.toggle()
            model.advance(by: 1)
            XCTAssertEqual(model.time, model.clip.duration)
            XCTAssertFalse(model.isPlaying)
            XCTAssertEqual(model.clip.lines.last!.words.last!.progress(at: model.time), 1)
            model.toggle()
            XCTAssertEqual(model.time, 0)
            XCTAssertTrue(model.isPlaying)
            XCTAssertEqual(model.clip.lines[0].words[0].progress(at: model.time), 0)
        }
    }
}
