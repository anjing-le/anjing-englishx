import Foundation
import Darwin

struct CodexConnectionReport: Sendable {
    let executable: String
    let model: String
    let defaultEffort: String
    let efforts: [String]
    let modalities: [String]
}

enum CodexProbeError: LocalizedError {
    case missing, login, closed, timeout, invalid, modelMissing, request(Int)
    var errorDescription: String? {
        switch self {
        case .missing: return "未找到本机 Codex，请先安装并登录。"
        case .login: return "Codex 尚未登录，请先在本机 Codex 中完成登录。"
        case .closed: return "Codex 连接中断，请重试。"
        case .timeout: return "检查连接超时，请重试。"
        case .invalid: return "无法读取 Codex 返回的信息，请检查 CLI 版本。"
        case .modelMissing: return "本机模型目录中未找到 gpt-6.1-sol，没有自动替换模型。"
        case .request(let code): return "Codex 检查失败（\(code)），请检查登录与网络状态。"
        }
    }
}

/// Read-only metadata check. Never creates a thread/turn or reads auth files.
enum CodexConnectionProbe {
    static func executable() -> String? {
        let env = ProcessInfo.processInfo.environment
        let configured = env["ENGLISHX_CODEX_EXECUTABLE"].map { ($0 as NSString).expandingTildeInPath }
        let paths = (env["PATH"] ?? "").split(separator: ":").map { String($0) + "/codex" }
        let candidates = [configured].compactMap { $0 } + paths + [
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func check() async throws -> CodexConnectionReport {
        try await Task.detached(priority: .userInitiated) { try inspect() }.value
    }
    private static func inspect() throws -> CodexConnectionReport {
        guard let path = executable() else { throw CodexProbeError.missing }
        let process = Process(), input = Pipe(), output = Pipe(), errors = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        let overrides = ["mcp_servers={}", "features.shell_tool=false", "features.apps=false",
                         "features.plugins=false", "features.hooks=false", "features.memories=false",
                         "web_search=\"disabled\"", "history.persistence=\"none\"", "analytics.enabled=false",
                         "otel.log_user_prompt=false", "notify=[]", "project_doc_max_bytes=0"]
        process.arguments = ["app-server", "--listen", "stdio://"] + overrides.flatMap { ["-c", $0] }
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = input; process.standardOutput = output; process.standardError = errors
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
        try process.run()
        let deadline = Date().addingTimeInterval(30)
        let timeout = DispatchWorkItem { [weak process] in if process?.isRunning == true { process?.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
        defer {
            timeout.cancel()
            errors.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
            try? errors.fileHandleForReading.close()
        }
        var buffer = Data(), requestID = 0
        func send(_ object: [String: Any]) throws {
            var bytes = try JSONSerialization.data(withJSONObject: object)
            bytes.append(0x0a)
            try input.fileHandleForWriting.write(contentsOf: bytes)
        }
        func request(_ method: String, _ params: [String: Any]) throws -> [String: Any] {
            requestID += 1
            let id = requestID
            try send(["id": id, "method": method, "params": params])
            while Date() < deadline {
                while let newline = buffer.firstIndex(of: 0x0a) {
                    let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                    guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { continue }
                    guard (message["id"] as? Int) == id else { continue }
                    if let error = message["error"] as? [String: Any] {
                        throw CodexProbeError.request(error["code"] as? Int ?? -1)
                    }
                    guard let result = message["result"] as? [String: Any] else { throw CodexProbeError.invalid }
                    return result
                }
                let bytes = output.fileHandleForReading.availableData
                guard !bytes.isEmpty else { throw Date() >= deadline ? CodexProbeError.timeout : CodexProbeError.closed }
                buffer.append(bytes)
                if buffer.count > 4 * 1024 * 1024 { throw CodexProbeError.invalid }
            }
            throw CodexProbeError.timeout
        }
        _ = try request("initialize", ["clientInfo": ["name": "englishx", "title": "EnglishX", "version": "0.0.1"],
                                       "capabilities": ["experimentalApi": false]])
        try send(["method": "initialized", "params": [:]])
        let account = try request("account/read", ["refreshToken": false])
        if account["requiresOpenaiAuth"] as? Bool == true,
           account["account"] == nil || account["account"] is NSNull { throw CodexProbeError.login }
        var cursor: String?
        for _ in 0..<10 {
            var params: [String: Any] = ["limit": 100, "includeHidden": false]
            if let cursor { params["cursor"] = cursor }
            let response = try request("model/list", params)
            guard let models = response["data"] as? [[String: Any]] else { throw CodexProbeError.invalid }
            if let model = models.first(where: { ($0["model"] as? String ?? $0["id"] as? String) == "gpt-6.1-sol" }) {
                let efforts = (model["supportedReasoningEfforts"] as? [[String: Any]] ?? [])
                    .compactMap { $0["reasoningEffort"] as? String }
                return CodexConnectionReport(executable: path, model: "gpt-6.1-sol",
                    defaultEffort: model["defaultReasoningEffort"] as? String ?? "low",
                    efforts: efforts, modalities: model["inputModalities"] as? [String] ?? [])
            }
            cursor = response["nextCursor"] as? String
            if cursor == nil { break }
        }
        throw CodexProbeError.modelMissing
    }
}
