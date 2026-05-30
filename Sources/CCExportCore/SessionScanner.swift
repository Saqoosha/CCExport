import Foundation

public enum SessionScanner {
    /// Default Claude Code projects directory.
    public static var projectsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    /// Scan all sessions, grouped by project directory.
    /// Groups are ordered by their most-recent session; sessions within a group
    /// are newest-first.
    public static func scanGroups(in root: URL = projectsDirectory) -> [SessionGroup] {
        let summaries = scan(in: root)
        let grouped = Dictionary(grouping: summaries, by: \.projectPath)
        return grouped
            .map { SessionGroup(projectPath: $0.key,
                                sessions: $0.value.sorted { $0.modified > $1.modified }) }
            .sorted { $0.mostRecent > $1.mostRecent }
    }

    /// Flat list of all session summaries (unsorted).
    public static func scan(in root: URL = projectsDirectory) -> [SessionSummary] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var summaries: [SessionSummary] = []
        for dir in projectDirs {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                  let files = try? fm.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: []
                  ) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                if let summary = summarize(file: file, fallbackDir: dir.lastPathComponent) {
                    summaries.append(summary)
                }
            }
        }
        return summaries
    }

    /// Read just enough of a file to build its list-row metadata.
    public static func summarize(file: URL, fallbackDir: String) -> SessionSummary? {
        let fm = FileManager.default
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast

        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }

        var cwd: String?
        var title: String?
        var bytesRead = 0
        let byteCap = 512 * 1024
        var buffer = Data()

        // Stream lines until we have both cwd and a title, or hit the byte cap.
        outer: while bytesRead < byteCap {
            guard let chunk = try? handle.read(upToCount: 64 * 1024), !chunk.isEmpty else { break }
            bytesRead += chunk.count
            buffer.append(chunk)

            while let nl = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                guard let obj = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any]
                else { continue }

                if cwd == nil, let c = obj["cwd"] as? String { cwd = c }
                if title == nil { title = extractTitle(obj) }
                if cwd != nil && title != nil { break outer }
            }
        }

        let projectPath = cwd ?? PathDecoding.decode(fallbackDir)
        let sessionID = file.deletingPathExtension().lastPathComponent
        _ = fm
        return SessionSummary(
            sessionID: sessionID, fileURL: file, projectPath: projectPath,
            title: title ?? "(no prompt)", modified: modified
        )
    }

    /// First human-typed prompt becomes the session title.
    private static func extractTitle(_ obj: [String: Any]) -> String? {
        let type = obj["type"] as? String
        if type == "queue-operation", (obj["operation"] as? String) == "enqueue",
           let raw = obj["content"] as? String {
            return firstLine(TextCleaning.clean(raw))
        }
        // Skip system-injected user messages (compaction summaries, skill bodies).
        if (obj["isCompactSummary"] as? Bool) == true || (obj["isMeta"] as? Bool) == true { return nil }
        guard type == "user", let message = obj["message"] as? [String: Any] else { return nil }
        if let s = message["content"] as? String, s.contains("<task-notification>") { return nil }
        var text = ""
        if let s = message["content"] as? String {
            text = TextCleaning.clean(s)
        } else if let array = message["content"] as? [Any] {
            // Skip tool_result-only user turns.
            for case let block as [String: Any] in array where (block["type"] as? String) == "text" {
                text = TextCleaning.clean(block["text"] as? String ?? "")
                if !text.isEmpty { break }
            }
        }
        return firstLine(text)
    }

    private static func firstLine(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let line = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return line.count <= 100 ? line : String(line.prefix(100)) + "…"
    }

    /// Resolve a session id (full or 8-char prefix) or an explicit path to a file URL.
    public static func resolve(idOrPath: String, in root: URL = projectsDirectory) -> URL? {
        if idOrPath.hasSuffix(".jsonl") {
            let url = URL(fileURLWithPath: (idOrPath as NSString).expandingTildeInPath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let matches = scan(in: root).filter { $0.sessionID.contains(idOrPath) }
        return matches.first?.fileURL
    }
}

/// Best-effort decode of an encoded project directory name. Lossy (the encoding
/// collapses `/` and `.` to `-`), so `cwd` from inside the file is preferred.
enum PathDecoding {
    static func decode(_ name: String) -> String {
        "/" + name.drop(while: { $0 == "-" }).replacingOccurrences(of: "-", with: "/")
    }
}
