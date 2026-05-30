import Foundation

enum DateParsing {
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }
}

/// Strips harness/system noise from a user/assistant text block so the export
/// shows what a human wrote, not injected context.
enum TextCleaning {
    private static func removeBlocks(_ text: String, tag: String) -> String {
        // Non-greedy removal of <tag>...</tag> including newlines.
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)>.*?</\(tag)>",
            options: [.dotMatchesLineSeparators]
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func extractFirstGroup(_ text: String, tag: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)>(.*?)</\(tag)>",
            options: [.dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// Clean a text block. Returns trimmed text (may be empty).
    static func clean(_ raw: String) -> String {
        var text = raw

        // Slash command invocations: render as the typed command.
        if text.contains("<command-name>") {
            let name = extractFirstGroup(text, tag: "command-name")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let args = extractFirstGroup(text, tag: "command-args")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty {
                let combined = args.isEmpty ? name : "\(name) \(args)"
                text = combined
            }
        }

        for tag in ["system-reminder", "local-command-caveat", "command-message",
                    "command-name", "command-args", "command-contents"] {
            text = removeBlocks(text, tag: tag)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum JSONUtil {
    /// Pretty-printed, key-sorted JSON for a value coming out of JSONSerialization.
    static func pretty(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ),
              let string = String(data: data, encoding: .utf8)
        else {
            return String(describing: value)
        }
        return string
    }

    /// Best-effort scalar string for a JSON value (used for gist fields).
    static func scalarString(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let b as Bool: return b ? "true" : "false"
        default: return nil
        }
    }
}
