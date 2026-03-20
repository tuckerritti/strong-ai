import SwiftUI
import SwiftData

@main
struct strong_aiApp: App {
    let container: ModelContainer

    init() {
        let container = try! ModelContainer(for: Exercise.self, WorkoutLog.self, UserProfile.self)
        self.container = container

        #if DEBUG
        if !UserDefaults.standard.bool(forKey: "hasSeededData") {
            SeedData.populate(container.mainContext)
            UserDefaults.standard.set(true, forKey: "hasSeededData")
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
