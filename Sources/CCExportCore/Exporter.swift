import Foundation

public enum Exporter {
    public static func defaultOutputDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/CCExport", isDirectory: true)
    }

    public static func defaultFileName(for session: ParsedSession) -> String {
        let project = session.projectPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "session"
        let safe = project.components(separatedBy: CharacterSet(charactersIn: "/ ")).joined(separator: "-")
        return "\(safe)-\(session.id.prefix(8)).html"
    }

    /// Render `session` to a self-contained HTML file. Returns the written URL.
    @discardableResult
    public static func export(session: ParsedSession, to url: URL? = nil,
                              exportedAt: Date = Date()) throws -> URL {
        let html = HTMLRenderer.render(session: session, exportedAt: exportedAt)
        let outURL = url ?? defaultOutputDirectory()
            .appendingPathComponent(defaultFileName(for: session))
        try FileManager.default.createDirectory(
            at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try html.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    /// Open a file in the default browser via `/usr/bin/open`. Returns whether the
    /// open command launched, so callers can report a failure instead of claiming
    /// success when nothing opened.
    @discardableResult
    public static func openInBrowser(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        do {
            try process.run()
            return true
        } catch {
            FileHandle.standardError.write(Data("warning: couldn't open \(url.path): \(error)\n".utf8))
            return false
        }
    }
}
