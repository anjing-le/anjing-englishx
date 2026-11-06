import Foundation

struct ProcessingEvent: Decodable, Sendable {
    let stage: String
    let message: String?
    let package: String?
}

enum ProcessingJobRunner {
    static func run(process: Process, receive: @escaping @MainActor @Sendable (ProcessingEvent) -> Void) async throws {
        try await Task.detached(priority: .userInitiated) {
            let output = Pipe(), errors = Pipe()
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output; process.standardError = errors
            errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
            defer { errors.fileHandleForReading.readabilityHandler = nil }
            try process.run()
            var buffer = Data()
            while true {
                let bytes = output.fileHandleForReading.availableData
                if bytes.isEmpty { break }
                buffer.append(bytes)
                guard buffer.count < 2 * 1024 * 1024 else { process.terminate(); throw CodexProbeError.invalid }
                while let newline = buffer.firstIndex(of: 0x0a) {
                    let row = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                    if let event = try? JSONDecoder().decode(ProcessingEvent.self, from: row) { await receive(event) }
                }
            }
            process.waitUntilExit()
            if process.terminationStatus != 0 { throw CodexProbeError.closed }
        }.value
    }
}
