import SwiftUI
import SwiftData
import os

private let appLogger = Logger(subsystem: "com.light-weight", category: "App")

@main
struct light_weightApp: App {
    let container: ModelContainer

    init() {
        appLogger.info("app_launch start")

        do {
            let config = ModelConfiguration(cloudKitDatabase: .none)
            container = try ModelContainer(for: Exercise.self, WorkoutLog.self, UserProfile.self, configurations: config)
            appLogger.info("model_container success cloudKitEnabled=false")
        } catch {
            appLogger.fault("model_container failure error=\(String(describing: error), privacy: .public)")
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }

        #if DEBUG
        appLogger.info("debug_seed start")
        SeedData.clearAll(container.mainContext)
        SeedData.populate(container.mainContext)
        if !Secrets.anthropicAPIKey.isEmpty {
            try? UserProfile.saveAPIKey(Secrets.anthropicAPIKey)
        }
        appLogger.info("debug_seed success apiKeyPreloaded=\(!Secrets.anthropicAPIKey.isEmpty, privacy: .public)")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
