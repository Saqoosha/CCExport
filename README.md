# CCExport

A native macOS app that browses your local Claude Code sessions and exports any
one of them to a **single, self-contained HTML file** — then opens it in your
browser.

- Sessions are listed newest-first with project name, and searchable.
- Export fidelity: conversation + tool calls, in a clean minimal document style.
- Tool calls and their results are foldable (`<details>`), so long output stays
  out of the way. The HTML needs **zero external assets** — open it anywhere.

## Build & run the app

The app is a standard Xcode project generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

```bash
./scripts/build.sh           # xcodegen generate → xcodebuild
open build/Build/Products/Debug/CCExport.app
```

Pick a session in the sidebar, hit **Export & Open** (⌘↵). The HTML lands in
`~/Desktop/CCExport/` and opens in your default browser. The first export may
prompt for permission to write to your Desktop — that's normal for a local app.

## CLI

A small companion CLI ships in the same package — handy for scripting:

```bash
swift run ccexport list                      # list all sessions
swift run ccexport export <id|path.jsonl>    # export + open
swift run ccexport export <id> --no-open     # write only
swift run ccexport export <id> --stdout      # HTML to stdout
swift run ccexport export <id> -o out.html   # custom path
```

`<id>` accepts a full session UUID or an 8-character prefix.

## How it works

Claude Code stores each session as a JSONL file under
`~/.claude/projects/<encoded-cwd>/<uuid>.jsonl`. CCExport:

1. **Scans** that directory, reading just enough of each file for a title + path.
2. **Parses** the selected session's JSONL into typed content blocks
   (text, tool_use, tool_result, thinking, image).
3. **Renders** Markdown (via `apple/swift-markdown`, GFM) and assembles a
   self-contained HTML document with inlined CSS and icons.

See [docs/DESIGN.md](docs/DESIGN.md) for the full design.

## Layout

```
project.yml         XcodeGen spec → CCExport.xcodeproj (the macOS app)
Package.swift       SwiftPM: CCExportCore library + ccexport CLI
Sources/
  CCExportCore/     parser · scanner · markdown→HTML · renderer · exporter
  CCExportApp/      SwiftUI app (session list + export) — the Xcode app target
  ccexport/         CLI
scripts/build.sh    xcodegen generate + xcodebuild → CCExport.app
```

The Xcode app target depends on `CCExportCore` as a local Swift package, so the
parser/renderer is shared between the app and the CLI.

## Notes

- Sub-agent (Task) calls show the prompt and final result. Their intermediate
  steps aren't reconstructed — current Claude Code versions don't store them in a
  recoverable form.
- `thinking` blocks are omitted by design (conversation + tools profile).
- Very large tool inputs/results are truncated in the export to keep file size sane.
