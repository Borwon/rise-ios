import SwiftUI
import SwiftData

@main
struct RISEApp: App {
    @State private var appState = AppState()

    private let container: ModelContainer

    init() {
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            fatalError("RISE. could not open its local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(RISETheme.Colors.primary)
        }
        .modelContainer(container)
    }
}
