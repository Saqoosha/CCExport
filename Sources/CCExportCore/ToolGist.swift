import Foundation

/// Produces a short one-line summary + selected fields for a tool call, so the
/// folded `<summary>` reads well without expanding.
enum ToolGist {
    static func make(name: String, input: [String: Any]) -> (gist: String?, fields: [String: String]) {
        func s(_ key: String) -> String? { JSONUtil.scalarString(input[key]) }

        var fields: [String: String] = [:]
        for key in ["file_path", "path", "command", "pattern", "url", "subagent_type",
                    "description", "prompt", "query", "old_string", "new_string", "content"] {
            if let v = s(key) { fields[key] = v }
        }

        let gist: String?
        switch name {
        case "Bash":
            gist = firstLine(s("command"))
        case "Read", "Edit", "Write", "NotebookEdit":
            gist = shortPath(s("file_path"))
        case "Glob", "Grep":
            let p = s("pattern") ?? ""
            let path = s("path").map { " · \(shortPath($0) ?? $0)" } ?? ""
            gist = p.isEmpty ? nil : "\(p)\(path)"
        case "LS":
            gist = shortPath(s("path"))
        case "WebFetch", "WebSearch":
            gist = s("url") ?? s("query")
        case "Task":
            let kind = s("subagent_type") ?? "agent"
            let desc = s("description").map { ": \($0)" } ?? ""
            gist = "\(kind)\(desc)"
        case "TodoWrite":
            if let todos = input["todos"] as? [Any] {
                gist = "\(todos.count) todos"
            } else {
                gist = nil
            }
        case "Skill":
            gist = s("command") ?? s("skill")
        default:
            gist = nil
        }
        return (gist?.isEmpty == true ? nil : gist, fields)
    }

    private static func firstLine(_ string: String?) -> String? {
        guard let string else { return nil }
        let line = string.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? string
        return truncate(line, 120)
    }

    private static func shortPath(_ path: String?) -> String? {
        guard let path else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private static func truncate(_ string: String, _ max: Int) -> String {
        string.count <= max ? string : String(string.prefix(max)) + "…"
    }
}
