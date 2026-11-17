import SwiftUI
import SwiftData

@main
struct RISEApp: App {
    @State private var appState = AppState()

    private let container: ModelContainer

    init() {
        do {
            let container = try PersistenceController.makeContainer()
            #if DEBUG
            LaunchOptions.seedDemoDataIfNeeded(context: ModelContext(container))
            if LaunchOptions.skipsOnboarding {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            #endif
            self.container = container
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
