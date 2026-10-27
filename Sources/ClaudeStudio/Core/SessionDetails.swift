import Foundation

struct SessionDetails: Equatable {

    enum Mode: String {
        case standard, acceptEdits, plan, auto, bypass

        var label: String {
            switch self {
            case .standard:    return "Default"
            case .acceptEdits: return "Accept edits"
            case .plan:        return "Plan"
            case .auto:        return "Auto"
            case .bypass:      return "Bypass"
            }
        }
    }

    var model: String?
    var contextTokens: Int?
    var mode: Mode?

    var contextLabel: String? {
        guard let tokens = contextTokens, tokens > 0 else { return nil }
        if tokens >= 1_000_000 { return String(format: "%.1fM context", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return "\(tokens / 1_000)k context" }
        return "\(tokens) context"
    }

    static func read(projectPath: String, sessionID: String?, tmux: String?,
                     previousMode: Mode?) -> SessionDetails {
        var details = SessionDetails()
        if let sessionID, !sessionID.isEmpty {
            (details.model, details.contextTokens) = transcriptTail(projectPath: projectPath,
                                                                    sessionID: sessionID)
        }
        if let tmux, let lines = Tmux.capturePanes([tmux])[tmux] {
            details.mode = mode(in: lines, previous: previousMode)
        }
        return details
    }

    static func mode(in lines: [String], previous: Mode?) -> Mode? {
        for line in lines.suffix(8).reversed() {
            let lower = line.lowercased()
            if lower.contains("plan mode on") { return .plan }
            if lower.contains("accept edits on") { return .acceptEdits }
            if lower.contains("bypass permissions on") { return .bypass }
            if lower.contains("auto mode on") { return .auto }
        }
        if PaneReader.read(lines).isAsking { return previous }
        return .standard
    }

    static func displayName(ofModel id: String) -> String {
        var name = id.hasPrefix("claude-") ? String(id.dropFirst("claude-".count)) : id
        if let bracket = name.firstIndex(of: "[") { name = String(name[..<bracket]) }
        var parts = name.split(separator: "-").map(String.init)
        if let last = parts.last, last.count == 8, Int(last) != nil { parts.removeLast() }
        guard let family = parts.first, family.first?.isLetter == true else { return id }
        let version = parts.dropFirst().filter { Int($0) != nil }.joined(separator: ".")
        let title = family.prefix(1).uppercased() + family.dropFirst()
        return version.isEmpty ? title : "\(title) \(version)"
    }

    private static func transcriptTail(projectPath: String, sessionID: String) -> (String?, Int?) {
        for directory in ClaudeTranscripts.directories(for: projectPath) {
            let url = directory.appendingPathComponent("\(sessionID).jsonl")
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            let window: UInt64 = 512 * 1024
            try? handle.seek(toOffset: size > window ? size - window : 0)
            guard let data = try? handle.readToEnd(),
                  let text = String(data: data, encoding: .utf8) else { continue }

            for line in text.split(separator: "\n").reversed() {
                guard line.contains("\"usage\""),
                      let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      object["type"] as? String == "assistant",
                      object["isSidechain"] as? Bool != true,
                      let message = object["message"] as? [String: Any],
                      let model = message["model"] as? String,
                      !model.hasPrefix("<"),
                      let usage = message["usage"] as? [String: Any]
                else { continue }
                let tokens = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
                    .reduce(0) { $0 + ((usage[$1] as? Int) ?? 0) }
                return (displayName(ofModel: model), tokens)
            }
        }
        return (nil, nil)
    }
}
