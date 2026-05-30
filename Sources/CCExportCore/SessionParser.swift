import Foundation

public enum SessionParser {
    /// Parse one session JSONL file into a `ParsedSession`.
    /// Parse a session JSONL file. `maxLines` caps how many leading lines are read
    /// (used for the live preview); nil reads the whole file.
    public static func parse(fileURL: URL, maxLines: Int? = nil) throws -> ParsedSession {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var objects: [[String: Any]] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let data = trimmed.data(using: .utf8),
               let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                objects.append(obj)
            }
            if let maxLines, lineCount >= maxLines { stop = true }
        }

        // Pre-scan: text of every delivered user message. A queued message
        // (queue-operation enqueue) is later delivered as a real user entry with
        // identical text, so the enqueue copy is dropped to avoid duplicates.
        var deliveredTexts = Set<String>()
        for obj in objects where (obj["type"] as? String) == "user" {
            if let text = rawUserText(obj) {
                deliveredTexts.insert(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        var entries: [SessionEntry] = []
        var cwd: String?
        var firstTS: Date?
        var lastTS: Date?
        for obj in objects {
            if cwd == nil, let c = obj["cwd"] as? String { cwd = c }
            guard let entry = parseEntry(obj, deliveredTexts: deliveredTexts) else { continue }
            if let ts = entry.timestamp {
                if firstTS == nil { firstTS = ts }
                lastTS = ts
            }
            entries.append(entry)
        }

        let id = fileURL.deletingPathExtension().lastPathComponent
        return ParsedSession(
            id: id, fileURL: fileURL, projectPath: cwd, entries: entries,
            firstTimestamp: firstTS, lastTimestamp: lastTS
        )
    }

    private static func parseEntry(_ obj: [String: Any], deliveredTexts: Set<String>) -> SessionEntry? {
        let type = obj["type"] as? String ?? ""
        let timestamp = DateParsing.date(from: obj["timestamp"] as? String)
        let cwd = obj["cwd"] as? String
        let isMeta = (obj["isMeta"] as? Bool) ?? false
        let isCompactSummary = (obj["isCompactSummary"] as? Bool) ?? false

        // Queued messages (typed/injected while Claude was working).
        if type == "queue-operation" {
            guard (obj["operation"] as? String) == "enqueue",
                  let raw = obj["content"] as? String else { return nil }
            // Drop the enqueue copy if the same message is delivered as a user entry.
            if deliveredTexts.contains(raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return nil }
            if let summary = notificationSummary(from: raw) {
                return SessionEntry(kind: .notification(summary: summary), timestamp: timestamp,
                                    blocks: [], cwd: cwd)
            }
            let text = TextCleaning.clean(raw)
            guard !text.isEmpty else { return nil }
            return SessionEntry(kind: .user, timestamp: timestamp, blocks: [.text(text)], cwd: cwd)
        }

        guard type == "user" || type == "assistant",
              let message = obj["message"] as? [String: Any] else { return nil }

        // Context compaction summary injected as a user message.
        if type == "user", isCompactSummary {
            let blocks = parseContent(message["content"])
            guard !blocks.isEmpty else { return nil }
            return SessionEntry(kind: .compactSummary, timestamp: timestamp, blocks: blocks, cwd: cwd)
        }

        // System notices delivered as user messages (background-task completions,
        // interrupt markers) — rendered as slim notes, not as "You" turns.
        if type == "user", let raw = rawUserText(obj), let note = systemNoteText(from: raw) {
            return SessionEntry(kind: .notification(summary: note), timestamp: timestamp,
                                blocks: [], cwd: cwd)
        }

        let blocks = parseContent(message["content"])
        guard !blocks.isEmpty else { return nil }
        return SessionEntry(kind: type == "assistant" ? .assistant : .user, timestamp: timestamp,
                            blocks: blocks, cwd: cwd, isMeta: isMeta)
    }

    /// Concatenated raw text of a user message (string content or text blocks).
    private static func rawUserText(_ obj: [String: Any]) -> String? {
        guard let message = obj["message"] as? [String: Any] else { return nil }
        if let string = message["content"] as? String { return string }
        if let array = message["content"] as? [Any] {
            var parts: [String] = []
            for case let block as [String: Any] in array where (block["type"] as? String) == "text" {
                parts.append(block["text"] as? String ?? "")
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }
        return nil
    }

    /// Map a system-injected user message to a short note, else nil (= real user text).
    private static func systemNoteText(from raw: String) -> String? {
        if let summary = notificationSummary(from: raw) { return summary }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[Request interrupted") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }
        return nil
    }

    /// Extract a one-line summary from a `<task-notification>` block, else nil.
    private static func notificationSummary(from raw: String) -> String? {
        guard raw.contains("<task-notification>") else { return nil }
        if let range = raw.range(of: #"<summary>(.*?)</summary>"#, options: .regularExpression) {
            let inner = raw[range]
                .replacingOccurrences(of: "<summary>", with: "")
                .replacingOccurrences(of: "</summary>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty { return inner }
        }
        return "Background task completed"
    }

    private static func parseContent(_ content: Any?) -> [ContentBlock] {
        if let string = content as? String {
            let text = TextCleaning.clean(string)
            return text.isEmpty ? [] : [.text(text)]
        }
        guard let array = content as? [Any] else { return [] }

        var blocks: [ContentBlock] = []
        for case let block as [String: Any] in array {
            switch block["type"] as? String {
            case "text":
                let text = TextCleaning.clean(block["text"] as? String ?? "")
                if !text.isEmpty { blocks.append(.text(text)) }
            case "thinking":
                let text = (block["thinking"] as? String ?? block["text"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { blocks.append(.thinking(text)) }
            case "tool_use":
                blocks.append(.toolUse(parseToolUse(block)))
            case "tool_result":
                blocks.append(.toolResult(parseToolResult(block)))
            case "image":
                if let img = parseImage(block["source"]) { blocks.append(.image(img)) }
            default:
                break
            }
        }
        return blocks
    }

    private static func parseToolUse(_ block: [String: Any]) -> ToolUse {
        let id = block["id"] as? String ?? ""
        let name = block["name"] as? String ?? "tool"
        let input = block["input"] as? [String: Any] ?? [:]
        let (gist, fields) = ToolGist.make(name: name, input: input)
        let pretty = input.isEmpty ? "" : JSONUtil.pretty(input)
        return ToolUse(id: id, name: name, inputPrettyJSON: pretty, gist: gist, fields: fields)
    }

    private static func parseToolResult(_ block: [String: Any]) -> ToolResult {
        let toolUseID = block["tool_use_id"] as? String
        let isError = (block["is_error"] as? Bool) ?? false
        var text = ""
        var images: [Base64Image] = []

        if let string = block["content"] as? String {
            text = string
        } else if let array = block["content"] as? [Any] {
            var parts: [String] = []
            for case let part as [String: Any] in array {
                switch part["type"] as? String {
                case "text":
                    if let t = part["text"] as? String { parts.append(t) }
                case "image":
                    if let img = parseImage(part["source"]) { images.append(img) }
                default:
                    break
                }
            }
            text = parts.joined(separator: "\n")
        }

        return ToolResult(
            toolUseID: toolUseID, isError: isError,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines), images: images
        )
    }

    private static func parseImage(_ source: Any?) -> Base64Image? {
        guard let source = source as? [String: Any] else { return nil }
        guard (source["type"] as? String) == "base64",
              let media = source["media_type"] as? String,
              let data = source["data"] as? String else { return nil }
        return Base64Image(mediaType: media, data: data)
    }
}
