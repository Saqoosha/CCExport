import Foundation

/// A base64-encoded inline image (from `image` blocks or image tool results).
public struct Base64Image: Sendable {
    public let mediaType: String
    public let data: String

    public init(mediaType: String, data: String) {
        self.mediaType = mediaType
        self.data = data
    }
}

/// A `tool_use` content block.
public struct ToolUse: Sendable {
    public let id: String
    public let name: String
    /// Pretty-printed JSON of the full input, for the details body.
    public let inputPrettyJSON: String
    /// One-line gist for the `<summary>` line (tool-specific, best effort).
    public let gist: String?
    /// Selected scalar string fields extracted from the input (Sendable-safe).
    public let fields: [String: String]

    public init(id: String, name: String, inputPrettyJSON: String, gist: String?, fields: [String: String]) {
        self.id = id
        self.name = name
        self.inputPrettyJSON = inputPrettyJSON
        self.gist = gist
        self.fields = fields
    }
}

/// A `tool_result` content block, flattened to text + any inline images.
public struct ToolResult: Sendable {
    public let toolUseID: String?
    public let isError: Bool
    public let text: String
    public let images: [Base64Image]

    public init(toolUseID: String?, isError: Bool, text: String, images: [Base64Image]) {
        self.toolUseID = toolUseID
        self.isError = isError
        self.text = text
        self.images = images
    }
}

/// A single content block inside a message.
public enum ContentBlock: Sendable {
    case text(String)
    case thinking(String)
    case toolUse(ToolUse)
    case toolResult(ToolResult)
    case image(Base64Image)
}

/// The kind of a renderable entry. A closed set — the raw JSONL `queue-operation`
/// is converted to `.user`/`.notification` at parse time and never reaches here.
public enum EntryKind: Sendable {
    case user
    case assistant
    /// A system note (background-task completion, interrupt marker) shown as a
    /// slim line; carries its own one-line summary.
    case notification(summary: String)
    /// A context-compaction summary injected by Claude Code; text is in `blocks`.
    case compactSummary
}

/// One JSONL line that carries renderable conversation content.
public struct SessionEntry: Sendable {
    public let kind: EntryKind
    public let timestamp: Date?
    public let blocks: [ContentBlock]
    public let cwd: String?
    /// `isMeta` on the JSONL line: system/skill-injected content delivered as a
    /// user/assistant message (not human-typed). Rendered folded. Only meaningful
    /// for `.user`/`.assistant`.
    public let isMeta: Bool

    public init(kind: EntryKind, timestamp: Date?, blocks: [ContentBlock],
                cwd: String?, isMeta: Bool = false) {
        self.kind = kind
        self.timestamp = timestamp
        self.blocks = blocks
        self.cwd = cwd
        self.isMeta = isMeta
    }
}

/// A fully parsed session.
public struct ParsedSession: Sendable {
    public let id: String
    public let fileURL: URL
    public let projectPath: String?
    public let entries: [SessionEntry]
    public let firstTimestamp: Date?
    public let lastTimestamp: Date?

    public init(id: String, fileURL: URL, projectPath: String?, entries: [SessionEntry],
                firstTimestamp: Date?, lastTimestamp: Date?) {
        self.id = id
        self.fileURL = fileURL
        self.projectPath = projectPath
        self.entries = entries
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }
}

/// Lightweight metadata for the session list (no full parse).
public struct SessionSummary: Sendable, Identifiable {
    /// Session UUID (the JSONL filename). Not unique across projects — a session
    /// can be resumed/copied under another cwd — so it is NOT the identity.
    public let sessionID: String
    public let fileURL: URL
    public let projectPath: String
    public let title: String
    public let modified: Date

    /// Stable, unique identity for lists/selection: the file path.
    public var id: String { fileURL.path }

    public init(sessionID: String, fileURL: URL, projectPath: String, title: String, modified: Date) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.projectPath = projectPath
        self.title = title
        self.modified = modified
    }
}

/// A directory group of sessions for the list UI.
public struct SessionGroup: Sendable, Identifiable {
    public let projectPath: String
    public let sessions: [SessionSummary]

    public var id: String { projectPath }
    public var mostRecent: Date { sessions.map(\.modified).max() ?? .distantPast }

    public init(projectPath: String, sessions: [SessionSummary]) {
        self.projectPath = projectPath
        self.sessions = sessions
    }
}
