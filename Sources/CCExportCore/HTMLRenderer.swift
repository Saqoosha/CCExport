import Foundation

public enum HTMLRenderer {
    /// Max characters shown for a single tool input / result before truncation.
    static let maxBlockChars = 8000

    /// Render a quick preview from the first `maxLines` lines of a session file.
    public static func previewHTML(fileURL: URL, maxLines: Int) -> String? {
        guard let session = try? SessionParser.parse(fileURL: fileURL, maxLines: maxLines) else {
            return nil
        }
        return render(session: session)
    }

    public static func render(session: ParsedSession, exportedAt: Date = Date()) -> String {
        let resultsByID = indexResults(session.entries)
        // Tool ids that a tool_use will render: their result is embedded there
        // regardless of where it appears (results sometimes precede the call).
        let embedded = collectToolUseIDs(session.entries)
        var body = ""
        var lastRole: String? = nil

        for entry in session.entries {
            if entry.type == "compact-summary" {
                body += compactSummaryBlock(entry)
                lastRole = "meta"
                continue
            }
            if entry.type == "notification" {
                if case .text(let summary) = entry.blocks.first {
                    body += "<div class=\"note\">\(HTMLEscaping.escape(summary))</div>\n"
                }
                continue
            }
            if entry.isMeta {
                let block = metaBlock(entry)
                if !block.isEmpty { body += block; lastRole = "meta" }
                continue
            }
            if entry.type == "assistant" {
                let inner = assistantBody(entry, results: resultsByID, embedded: embedded)
                guard !inner.isEmpty else { continue }
                if lastRole == "claude" {
                    let toolOnly = hasProse(entry) ? "" : " tool-only"
                    body += "<div class=\"turn claude continued\(toolOnly)\"><div class=\"body\">\(inner)</div></div>\n"
                } else {
                    body += turn(role: "claude", name: "Claude", icon: Assets.claudeLogoSVG,
                                 time: entry.timestamp, inner: inner)
                }
                lastRole = "claude"
            } else {
                let parts = userBody(entry, embedded: embedded)
                if !parts.human.isEmpty {
                    body += turn(role: "you", name: "You", icon: Assets.userIconSVG,
                                 time: entry.timestamp, inner: parts.human)
                    lastRole = "you"
                }
                if !parts.orphanTools.isEmpty {
                    body += parts.orphanTools
                    lastRole = "claude"
                }
            }
        }

        return document(session: session, exportedAt: exportedAt, body: body)
    }

    /// Tool-use ids that appear in assistant turns — these tool calls render and
    /// embed their result, so the same result must not also render standalone.
    private static func collectToolUseIDs(_ entries: [SessionEntry]) -> Set<String> {
        var ids = Set<String>()
        for entry in entries where entry.type == "assistant" {
            for case .toolUse(let tool) in entry.blocks { ids.insert(tool.id) }
        }
        return ids
    }

    /// Map every `tool_result` to the `tool_use` id it answers, so results can be
    /// embedded inside the matching tool's `<details>`.
    private static func indexResults(_ entries: [SessionEntry]) -> [String: ToolResult] {
        var map: [String: ToolResult] = [:]
        for entry in entries {
            for case .toolResult(let result) in entry.blocks {
                if let id = result.toolUseID { map[id] = result }
            }
        }
        return map
    }

    /// Whether an entry carries human-readable prose (text/image), as opposed to
    /// being only tool calls — used to tighten spacing between tool-only steps.
    private static func hasProse(_ entry: SessionEntry) -> Bool {
        entry.blocks.contains { block in
            switch block {
            case .text, .image: return true
            default: return false
            }
        }
    }

    // MARK: - Turn assembly

    private static func turn(role: String, name: String, icon: String,
                             time: Date?, inner: String) -> String {
        let ts = time.map { "<span class=\"time\">\(formatTime($0))</span>" } ?? ""
        return """
        <div class="turn \(role)">
        <div class="role \(role)"><span class="icon">\(icon)</span><span class="name">\(name)</span>\(ts)</div>
        <div class="body">\(inner)</div>
        </div>

        """
    }

    private static func assistantBody(_ entry: SessionEntry, results: [String: ToolResult],
                                      embedded: Set<String>) -> String {
        var out = ""
        for block in entry.blocks {
            switch block {
            case .text(let text):
                out += "<div class=\"md\">\(MarkdownRenderer.html(from: text))</div>\n"
            case .thinking:
                continue
            case .image(let img):
                out += imageTag(img)
            case .toolUse(let tool):
                out += toolBlock(tool, result: results[tool.id])
            case .toolResult(let result):
                if let id = result.toolUseID, embedded.contains(id) { continue }
                out += orphanResult(result)
            }
        }
        return out
    }

    /// A user turn split into human-authored content and any orphan tool output
    /// (a result whose tool_use isn't in the transcript). Orphan output is not
    /// shown inside a "You" box.
    private static func userBody(_ entry: SessionEntry, embedded: Set<String>) -> (human: String, orphanTools: String) {
        var human = ""
        var orphan = ""
        for block in entry.blocks {
            switch block {
            case .text(let text):
                human += "<div class=\"md\">\(MarkdownRenderer.html(from: text))</div>\n"
            case .image(let img):
                human += imageTag(img)
            case .thinking:
                continue
            case .toolUse(let tool):
                human += toolBlock(tool, result: nil)
            case .toolResult(let result):
                if let id = result.toolUseID, embedded.contains(id) { continue }
                if !result.text.isEmpty || !result.images.isEmpty {
                    orphan += orphanResult(result)
                }
            }
        }
        return (human, orphan)
    }

    /// A tool result with no rendered tool_use — shown as a standalone folded
    /// tool block, never as a "You" message.
    private static func orphanResult(_ result: ToolResult) -> String {
        """
        <details class="tool">
        <summary><span class="tool-name">tool output</span></summary>
        <div class="tool-body">\(resultBlock(result, standalone: false))</div>
        </details>

        """
    }

    /// System/skill-injected content (`isMeta`) — folded and de-emphasized.
    private static func metaBlock(_ entry: SessionEntry) -> String {
        var inner = ""
        var firstText = ""
        for block in entry.blocks {
            switch block {
            case .text(let text):
                if firstText.isEmpty { firstText = text }
                inner += "<div class=\"md\">\(MarkdownRenderer.html(from: text))</div>\n"
            case .image(let img):
                inner += imageTag(img)
            case .toolResult, .toolUse, .thinking:
                continue
            }
        }
        guard !inner.isEmpty else { return "" }
        let label = metaLabel(from: firstText)
        return """
        <div class="turn meta-turn">
        <details class="meta">
        <summary><span class="meta-tag">context</span><span class="meta-gist">\(HTMLEscaping.escape(label))</span></summary>
        <div class="meta-body">\(inner)</div>
        </details>
        </div>

        """
    }

    /// Context-compaction summary — folded, labelled as a summary boundary.
    private static func compactSummaryBlock(_ entry: SessionEntry) -> String {
        var inner = ""
        for case .text(let text) in entry.blocks {
            inner += "<div class=\"md\">\(MarkdownRenderer.html(from: text))</div>\n"
        }
        guard !inner.isEmpty else { return "" }
        return """
        <div class="turn meta-turn">
        <details class="meta compact">
        <summary><span class="meta-tag">summary</span><span class="meta-gist">compacted from an earlier conversation</span></summary>
        <div class="meta-body">\(inner)</div>
        </details>
        </div>

        """
    }

    private static func metaLabel(from text: String) -> String {
        if let range = text.range(of: #"skills/([^/\s]+)"#, options: .regularExpression) {
            let name = text[range].split(separator: "/").last.map(String.init) ?? ""
            if !name.isEmpty { return "skill: \(name)" }
        }
        let line = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count <= 80 ? trimmed : String(trimmed.prefix(80)) + "…"
    }

    // MARK: - Tool rendering

    private static func toolBlock(_ tool: ToolUse, result: ToolResult?) -> String {
        let isTask = tool.name == "Task"
        let cls = isTask ? "tool sub" : "tool"
        let gist = tool.gist.map { "<span class=\"tool-gist\">\(HTMLEscaping.escape($0))</span>" } ?? ""

        var inner = ""
        if isTask {
            if let kind = tool.fields["subagent_type"] {
                inner += "<div class=\"tool-kv\">subagent: \(HTMLEscaping.escape(kind))</div>\n"
            }
            if let prompt = tool.fields["prompt"], !prompt.isEmpty {
                inner += """
                <details><summary class="tool-result-label" style="cursor:pointer">prompt</summary>
                <pre><code>\(truncatedEscaped(prompt))</code></pre></details>

                """
            }
        } else if !tool.inputPrettyJSON.isEmpty {
            inner += "<pre class=\"tool-input\"><code>\(truncatedEscaped(tool.inputPrettyJSON))</code></pre>\n"
        }

        if let result {
            inner += resultBlock(result, standalone: false, label: isTask ? "result" : "output")
        }

        return """
        <details class="\(cls)">
        <summary><span class="tool-name">\(HTMLEscaping.escape(tool.name))</span>\(gist)</summary>
        <div class="tool-body">\(inner)</div>
        </details>

        """
    }

    private static func resultBlock(_ result: ToolResult, standalone: Bool,
                                    label: String = "output") -> String {
        var out = "<div class=\"tool-result\(result.isError ? " error" : "")\">"
        if standalone || !result.text.isEmpty || !result.images.isEmpty {
            out += "<div class=\"tool-result-label\">\(result.isError ? "error" : label)</div>"
        }
        if !result.text.isEmpty {
            out += "<pre><code>\(truncatedEscaped(result.text))</code></pre>"
        }
        for img in result.images { out += imageTag(img) }
        out += "</div>"
        return out
    }

    private static func imageTag(_ img: Base64Image) -> String {
        "<img class=\"inline-image\" src=\"data:\(img.mediaType);base64,\(img.data)\" alt=\"\">\n"
    }

    // MARK: - Document shell

    private static func document(session: ParsedSession, exportedAt: Date, body: String) -> String {
        let title = sessionTitle(session)
        var dl = ""
        func row(_ k: String, _ v: String) {
            dl += "<dt>\(k)</dt><dd>\(HTMLEscaping.escape(v))</dd>"
        }
        if let project = session.projectPath { row("Project", abbreviate(project)) }
        row("Session", session.id)
        if let first = session.firstTimestamp, let last = session.lastTimestamp {
            row("Time", "\(formatTime(first)) – \(formatTime(last))")
        }
        row("Exported", formatTime(exportedAt))

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(HTMLEscaping.escape(title))</title>
        <style>
        \(Assets.css)
        </style>
        </head>
        <body>
        <main class="wrap">
        <header class="meta">
        <h1>\(HTMLEscaping.escape(title))</h1>
        <dl>\(dl)</dl>
        </header>
        \(body)
        </main>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private static func sessionTitle(_ session: ParsedSession) -> String {
        for entry in session.entries where entry.type == "user" {
            for case .text(let t) in entry.blocks {
                let line = t.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? t
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    return trimmed.count <= 90 ? trimmed : String(trimmed.prefix(90)) + "…"
                }
            }
        }
        return "Claude Code Session"
    }

    private static func truncatedEscaped(_ text: String) -> String {
        if text.count <= maxBlockChars {
            return HTMLEscaping.escape(text)
        }
        let head = String(text.prefix(maxBlockChars))
        let omitted = text.count - maxBlockChars
        return HTMLEscaping.escape(head)
            + "\n<span class=\"truncated\">… (\(omitted) more characters truncated)</span>"
    }

    private static func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
