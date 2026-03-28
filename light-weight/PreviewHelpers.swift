import Foundation
import SwiftData

extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        do {
            let container = try ModelContainer(
                for: Exercise.self, WorkoutLog.self, UserProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            SeedData.populate(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error.localizedDescription)")
        }
    }
}
