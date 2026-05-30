# CCExport — Design

A macOS app that browses local Claude Code sessions and exports any session to a
single, self-contained HTML file, then opens it in the default browser.

## Goals

- Native macOS app (SwiftUI).
- Browse sessions: recent first, grouped by project directory, searchable.
- Export a selected session to **one self-contained HTML file** (no external assets).
- Fidelity: conversation + tool calls (lightweight). Minimal, document-style look.
- Open the generated HTML in the external browser. No in-app HTML preview.

## Data source (verified against real sessions)

- Sessions live at `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl`.
  Directory names encode the cwd, e.g. `-Users-hiko-Documents-repos-Personal-CCExport`
  → `/Users/hiko/Documents/repos/Personal/CCExport`.
- Each line is a JSON object. Relevant `type` values:
  `user`, `assistant`, `system`, `queue-operation`, `progress`,
  `file-history-snapshot`, `attachment`, `last-prompt`.
- `message.content` is either a string or an array of blocks:
  `text`, `tool_use`, `tool_result`, `thinking`, `image`, `document`.
- Timestamps are ISO-8601 (`...Z`).
- Sub-agents (Task tool) in current Claude Code versions appear as `progress`
  entries with `data.type == "agent_progress"` and `parentToolUseID` pointing at the
  Task `tool_use` id — **but their `message` / `normalizedMessages` payloads are
  empty**, so the intermediate sub-agent transcript cannot be reconstructed.
  The reliable sub-agent data is the Task `tool_use` (`prompt`, `subagent_type`,
  `description`) and its matching `tool_result` (final output).

## Modules

| Module | Responsibility | Depends on |
|---|---|---|
| `Models` | `SessionEntry`, `ChatMessage`, `ContentBlock` (enum) | — |
| `SessionScanner` | enumerate projects dir → `[SessionSummary]` (title, decoded path, mtime, count) | Foundation |
| `SessionParser` | one JSONL file → `[SessionEntry]` with typed blocks | Foundation |
| `MarkdownRenderer` | Markdown text → HTML (GFM: tables, task lists, code) | swift-markdown |
| `HTMLRenderer` | parsed session → self-contained HTML string | MarkdownRenderer |
| `Exporter` | write HTML file + open in browser | AppKit |
| `CCExport` (app) | SwiftUI `NavigationSplitView`: list + search + export | SwiftUI, Core |
| `ccexport` (cli) | `export <id>` / `list` — dev + automation harness | Core |

Scanning is lightweight (title = first user message, time = file mtime). Full
parsing happens only at export time.

## HTML output (conversation + tools, minimal doc style)

- **Self-contained**: CSS inlined in `<style>`; icons inline SVG; zero external
  requests. System font stack.
- **Collapsible** via native `<details>/<summary>` → works with **zero JS**.
- **Turns**: `You` / `Claude` labels with a small inline icon (Claude logo SVG).
- **Markdown**: assistant/user text rendered to HTML (code fences, lists, tables).
- **Tool calls**: folded `<details>`; summary = tool name (Bash/Read/Edit/Write/
  Task get a one-line gist); body = pretty-printed input.
- **Tool results**: folded `<details>`; `image` blocks inlined as base64 `<img>`.
- **thinking**: omitted by default (conversation + tools profile).
- **Sub-agents (Task)**: folded `<details>` at the call site — `subagent_type` +
  `description` as summary; body shows the prompt and the final result. Intermediate
  steps are intentionally not reconstructed (not available in current format).
- **Header**: project path, session id, time range, entry count, export timestamp.

## Export behavior

`Export & Open` → writes `~/Desktop/CCExport/<project>-<id8>.html` → opens it with
`NSWorkspace.open`. Output directory configurable later; v1 defaults to Desktop.

## Packaging / tech choices

- **Swift Package** (CLI-buildable, no hand-written `.xcodeproj`):
  - `CCExportCore` library, `CCExport` SwiftUI app executable, `ccexport` CLI.
  - `Scripts/bundle.sh` wraps the release binary into a double-clickable `CCExport.app`.
- **Non-sandboxed** (needs to read `~/.claude`).
- **Markdown**: `apple/swift-markdown` + a custom HTML visitor (GFM tables, task
  lists, strikethrough). Falls back to a built-in minimal renderer if the dependency
  is unavailable.
- Bundle id: `sh.saqoo.ccexport`.
