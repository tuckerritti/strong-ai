import Foundation
import SwiftData

enum ExerciseLibraryService {
    static func persist(
        workoutExercises: [WorkoutExercise],
        existingExercises: [Exercise],
        modelContext: ModelContext
    ) {
        var knownNames = Set(existingExercises.map { normalize($0.name) })

        for workoutExercise in workoutExercises {
            let trimmedName = workoutExercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedGroup = workoutExercise.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = normalize(trimmedName)

            guard !normalizedName.isEmpty, !trimmedGroup.isEmpty else { continue }
            guard knownNames.insert(normalizedName).inserted else { continue }

            modelContext.insert(Exercise(name: trimmedName, muscleGroup: trimmedGroup))
        }
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
