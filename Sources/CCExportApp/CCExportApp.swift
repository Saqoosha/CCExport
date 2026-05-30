import SwiftUI

@main
struct CCExportApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
