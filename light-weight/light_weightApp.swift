import SwiftUI
import SwiftData

@main
struct light_weightApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Exercise.self, WorkoutLog.self, UserProfile.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }

        #if DEBUG
        SeedData.clearAll(container.mainContext)
        SeedData.populate(container.mainContext)
        if !Secrets.anthropicAPIKey.isEmpty {
            try? UserProfile.saveAPIKey(Secrets.anthropicAPIKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
