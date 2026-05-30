import Foundation
import CCExportCore

func printUsage() {
    print("""
    ccexport — export a Claude Code session to a single HTML file

    USAGE:
      ccexport list
      ccexport export <session-id | path.jsonl> [options]

    OPTIONS (export):
      -o, --output <path>   Output HTML path (default: ~/Desktop/CCExport/<name>.html)
      --no-open             Do not open the result in the browser
      --stdout              Write HTML to stdout instead of a file
    """)
}

func runList() {
    let groups = SessionScanner.scanGroups()
    if groups.isEmpty {
        FileHandle.standardError.write(Data("No sessions found under ~/.claude/projects\n".utf8))
        return
    }
    for group in groups {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let label = group.projectPath.hasPrefix(home)
            ? "~" + group.projectPath.dropFirst(home.count) : group.projectPath
        print("\n\(label)")
        for session in group.sessions {
            let date = session.modified.formatted(date: .abbreviated, time: .shortened)
            print("  \(session.sessionID.prefix(8))  \(date)  \(session.title)")
        }
    }
}

func runExport(_ args: [String]) {
    guard let target = args.first else {
        FileHandle.standardError.write(Data("error: missing <session-id | path>\n".utf8))
        exit(2)
    }

    var output: URL?
    var open = true
    var toStdout = false
    var i = 1
    while i < args.count {
        switch args[i] {
        case "-o", "--output":
            i += 1
            guard i < args.count else {
                FileHandle.standardError.write(Data("error: \(args[i - 1]) requires a path\n".utf8))
                exit(2)
            }
            output = URL(fileURLWithPath: (args[i] as NSString).expandingTildeInPath)
        case "--no-open": open = false
        case "--stdout": toStdout = true
        default: break
        }
        i += 1
    }

    guard let fileURL = SessionScanner.resolve(idOrPath: target) else {
        FileHandle.standardError.write(Data("error: no session matching '\(target)'\n".utf8))
        exit(1)
    }

    do {
        let session = try SessionParser.parse(fileURL: fileURL)
        if toStdout {
            print(HTMLRenderer.render(session: session))
            return
        }
        let out = try Exporter.export(session: session, to: output)
        let size = (try? out.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        print("Exported \(session.entries.count) entries → \(out.path) (\(size / 1024) KB)")
        if open, !Exporter.openInBrowser(out) {
            FileHandle.standardError.write(Data("warning: exported, but couldn't open the browser\n".utf8))
        }
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "list":
    runList()
case "export":
    runExport(Array(arguments.dropFirst()))
case "-h", "--help", .none:
    printUsage()
default:
    FileHandle.standardError.write(Data("unknown command: \(arguments[0])\n".utf8))
    printUsage()
    exit(2)
}
