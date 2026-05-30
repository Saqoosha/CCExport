import Foundation
import Observation
import CCExportCore

@MainActor
@Observable
final class SessionStore {
    var sessions: [SessionSummary] = []
    var isLoading = false
    var search = ""
    var selection: SessionSummary.ID?
    var status: Status?

    enum Status {
        case success(String, URL)
        case failure(String)
    }

    /// Flat list, newest first, filtered by the search query.
    var filteredSessions: [SessionSummary] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.lowercased().contains(query)
                || $0.projectPath.lowercased().contains(query)
                || $0.sessionID.lowercased().contains(query)
        }
    }

    var selectedSummary: SessionSummary? {
        guard let id = selection else { return nil }
        return sessions.first { $0.id == id }
    }

    func load() {
        isLoading = true
        Task {
            let scanned = await Task.detached(priority: .userInitiated) {
                SessionScanner.scan().sorted { $0.modified > $1.modified }
            }.value
            self.sessions = scanned
            self.isLoading = false
        }
    }

    func export(_ summary: SessionSummary) {
        status = nil
        Task {
            let result: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
                do {
                    let session = try SessionParser.parse(fileURL: summary.fileURL)
                    return .success(try Exporter.export(session: session))
                } catch {
                    return .failure(error)
                }
            }.value

            switch result {
            case .success(let url):
                Exporter.openInBrowser(url)
                status = .success(url.lastPathComponent, url)
            case .failure(let error):
                status = .failure(error.localizedDescription)
            }
        }
    }
}
