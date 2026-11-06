import XCTest
import AppKit
import UniformTypeIdentifiers
@testable import EnglishX

final class VideoDropTests: XCTestCase {
    func testProcessingDoesNotAcceptAnotherDrop() async {
        await MainActor.run {
            let model = ProcessingSettingsModel(); model.processing = true
            let provider = NSItemProvider(item: URL(fileURLWithPath: "/tmp/unused.mp4") as NSURL, typeIdentifier: UTType.fileURL.identifier)
            XCTAssertFalse(model.acceptDrop([provider]))
            XCTAssertNil(model.video)
        }
    }
    func testLocalFileDropReadsRealVideoAndThumbnail() async throws {
        let executable = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw XCTSkip("ffmpeg not installed") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("drop-test.mp4")
        let process = Process(); process.executableURL = executable
        process.arguments = ["-nostdin", "-y", "-f", "lavfi", "-i", "color=c=blue:s=160x90:r=10:d=1", "-f", "lavfi", "-i", "anullsrc=r=16000:cl=mono", "-t", "1", "-c:v", "libx264", "-c:a", "aac", "-pix_fmt", "yuv420p", url.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        let model = await MainActor.run { ProcessingSettingsModel() }
        let accepted = await MainActor.run {
            model.acceptDrop([NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)])
        }
        XCTAssertTrue(accepted)
        for _ in 0..<150 {
            if await MainActor.run(body: { model.video != nil && !model.inspectingVideo }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        await MainActor.run {
            XCTAssertEqual(model.video?.url, url)
            XCTAssertEqual(model.video?.audioTracks, 1)
            XCTAssertNotNil(model.thumbnail)
            XCTAssertFalse(model.videoFailed)
            XCTAssertFalse(model.processing) // dropping never automatically starts model processing
        }
    }
}
