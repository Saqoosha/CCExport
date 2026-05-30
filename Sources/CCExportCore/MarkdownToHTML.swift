import Foundation
import Markdown

enum HTMLEscaping {
    static func escape(_ string: String) -> String {
        var out = ""
        out.reserveCapacity(string.count)
        for ch in string {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(ch)
            }
        }
        return out
    }

    static func escapeAttribute(_ string: String) -> String {
        escape(string).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Renders CommonMark/GFM markdown to HTML.
public enum MarkdownRenderer {
    public static func html(from markdown: String) -> String {
        let document = Document(parsing: markdown)
        var visitor = HTMLMarkupVisitor()
        return visitor.visit(document)
    }
}

private struct HTMLMarkupVisitor: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: Markup) -> String {
        renderChildren(of: markup)
    }

    private mutating func renderChildren(of markup: Markup) -> String {
        var out = ""
        for child in markup.children { out += visit(child) }
        return out
    }

    mutating func visitDocument(_ document: Document) -> String {
        renderChildren(of: document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(renderChildren(of: paragraph))</p>\n"
    }

    mutating func visitText(_ text: Text) -> String {
        HTMLEscaping.escape(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(renderChildren(of: emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(renderChildren(of: strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(renderChildren(of: strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(HTMLEscaping.escape(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let lang = (codeBlock.language ?? "").trimmingCharacters(in: .whitespaces)
        let cls = lang.isEmpty ? "" : " class=\"language-\(HTMLEscaping.escapeAttribute(lang))\""
        return "<pre><code\(cls)>\(HTMLEscaping.escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String { html.rawHTML }
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String { inlineHTML.rawHTML }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String { "<br>\n" }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String { "\n" }
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String { "<hr>\n" }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>\(renderChildren(of: heading))</h\(level)>\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let dest = HTMLEscaping.escapeAttribute(link.destination ?? "")
        return "<a href=\"\(dest)\">\(renderChildren(of: link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = HTMLEscaping.escapeAttribute(image.source ?? "")
        return "<img src=\"\(src)\" alt=\"\">"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\n\(renderChildren(of: blockQuote))</blockquote>\n"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        "<ul>\n\(renderChildren(of: list))</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        "<ol>\n\(renderChildren(of: list))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            return "<li class=\"task\"><input type=\"checkbox\" disabled\(checked)> "
                + "\(renderChildren(of: listItem))</li>\n"
        }
        return "<li>\(renderChildren(of: listItem))</li>\n"
    }

    mutating func visitTable(_ table: Table) -> String {
        var out = "<table>\n<thead>\n<tr>"
        for case let cell as Table.Cell in table.head.children {
            out += "<th>\(renderChildren(of: cell))</th>"
        }
        out += "</tr>\n</thead>\n<tbody>\n"
        for case let row as Table.Row in table.body.children {
            out += "<tr>"
            for case let cell as Table.Cell in row.children {
                out += "<td>\(renderChildren(of: cell))</td>"
            }
            out += "</tr>\n"
        }
        out += "</tbody>\n</table>\n"
        return out
    }

    mutating func visitTableCell(_ cell: Table.Cell) -> String {
        renderChildren(of: cell)
    }
}
