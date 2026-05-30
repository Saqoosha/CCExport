import SwiftUI
import CCExportCore

struct SessionDetailView: View {
    @Bindable var store: SessionStore

    var body: some View {
        if let summary = store.selectedSummary {
            detail(summary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("Select a session",
                                   systemImage: "doc.text",
                                   description: Text("Choose a session to export as a single HTML file."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detail(_ summary: SessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title).font(.title3).fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(projectLabel(summary.projectPath))
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                metaRow("Session", String(summary.sessionID.prefix(8)))
                metaRow("Modified", summary.modified.formatted(date: .complete, time: .shortened))
                metaRow("File", summary.fileURL.path)
            }
            .font(.system(size: 12))

            Button {
                store.export(summary)
            } label: {
                Label("Export & Open", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)

            statusView
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch store.status {
        case .success(let name, let url):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Exported \(name)")
                Button("Show in Finder") { revealInFinder(url) }
                    .buttonStyle(.link)
            }
            .font(.system(size: 12))
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.system(size: 12))
        case .none:
            EmptyView()
        }
    }

    private func metaRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(.tertiary)
            Text(value).textSelection(.enabled).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }
    }

    private func projectLabel(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func revealInFinder(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-R", url.path]
        try? process.run()
    }
}
