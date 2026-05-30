import SwiftUI
import AppKit
import CCExportCore

private let previewLineCount = 500

struct SessionDetailView: View {
    @Bindable var store: SessionStore
    @State private var previewState: PreviewState = .loading

    private enum PreviewState {
        case loading
        case ready(String)
        case failed
    }

    var body: some View {
        if let summary = store.selectedSummary {
            VStack(spacing: 0) {
                header(summary)
                statusBar
                Divider()
                preview
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: summary.id) { await loadPreview(summary) }
        } else {
            ContentUnavailableView("Select a session",
                                   systemImage: "doc.text",
                                   description: Text("Choose a session to export as a single HTML file."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private func header(_ summary: SessionSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title).font(.headline).lineLimit(2)
                HStack(spacing: 6) {
                    Text(projectLabel(summary.projectPath))
                        .lineLimit(1).truncationMode(.middle)
                    Text("· preview: first \(previewLineCount) lines")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { store.export(summary) } label: {
                Label("Export & Open", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .fixedSize()
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusBar: some View {
        switch store.status {
        case .success(let name, let url, let opened):
            statusLine {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(opened ? "Exported \(name)" : "Exported \(name) — couldn't open the browser")
                Button("Show in Finder") { revealInFinder(url) }.buttonStyle(.link)
            }
        case .failure(let message):
            statusLine {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message)
            }
        case .none:
            EmptyView()
        }
    }

    private func statusLine<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.bottom, 8)
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch previewState {
        case .ready(let html):
            HTMLPreview(html: html)
        case .failed:
            ContentUnavailableView("Couldn't render preview",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("This session file couldn't be read or parsed."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Rendering preview…").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadPreview(_ summary: SessionSummary) async {
        previewState = .loading
        let url = summary.fileURL
        let html = await Task.detached(priority: .userInitiated) {
            HTMLRenderer.previewHTML(fileURL: url, maxLines: previewLineCount)
        }.value
        previewState = html.map(PreviewState.ready) ?? .failed
    }

    // MARK: - Helpers

    private func projectLabel(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
