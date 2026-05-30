import SwiftUI
import CCExportCore

struct ContentView: View {
    @State private var store = SessionStore()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 460)
        } detail: {
            SessionDetailView(store: store)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
        .task { if store.sessions.isEmpty { store.load() } }
    }

    private var sidebar: some View {
        @Bindable var store = store
        return List(selection: $store.selection) {
            ForEach(store.filteredSessions) { session in
                SessionRow(summary: session, isSelected: store.selection == session.id)
                    .tag(session.id)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $store.search, placement: .sidebar, prompt: "Search sessions")
        .overlay {
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else if store.filteredSessions.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "tray", description: Text(emptyMessage))
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem {
                Button { store.load() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Rescan ~/.claude/projects")
            }
        }
    }

    private var isSearching: Bool {
        !store.search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var projectsDirectoryExists: Bool {
        FileManager.default.fileExists(atPath: SessionScanner.projectsDirectory.path)
    }

    private var emptyTitle: String {
        if isSearching { return "No matches" }
        return projectsDirectoryExists ? "No sessions" : "No projects folder"
    }

    private var emptyMessage: String {
        if isSearching { return "No sessions match your search." }
        return projectsDirectoryExists
            ? "No Claude Code sessions found in ~/.claude/projects."
            : "~/.claude/projects wasn't found."
    }
}

struct SessionRow: View {
    let summary: SessionSummary
    var isSelected: Bool = false

    private var projectName: String {
        let name = URL(fileURLWithPath: summary.projectPath).lastPathComponent
        return name.isEmpty ? summary.projectPath : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(summary.title).lineLimit(1).font(.system(size: 13))
            HStack(spacing: 6) {
                Text(projectName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.accentColor)
                    .lineLimit(1)
                Text(summary.modified.formatted(
                    .dateTime.year().month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
