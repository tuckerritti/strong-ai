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
            _ = insertExercise(
                name: workoutExercise.name,
                muscleGroup: workoutExercise.muscleGroup,
                knownNames: &knownNames,
                modelContext: modelContext
            )
        }
    }

    static func containsExercise(named name: String, existingExercises: [Exercise]) -> Bool {
        let normalizedName = normalize(name)
        guard !normalizedName.isEmpty else { return false }
        return existingExercises.contains { normalize($0.name) == normalizedName }
    }

    static func addExercise(
        name: String,
        muscleGroup: String,
        existingExercises: [Exercise],
        modelContext: ModelContext
    ) -> Bool {
        var knownNames = Set(existingExercises.map { normalize($0.name) })
        return insertExercise(
            name: name,
            muscleGroup: muscleGroup,
            knownNames: &knownNames,
            modelContext: modelContext
        )
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @discardableResult
    private static func insertExercise(
        name: String,
        muscleGroup: String,
        knownNames: inout Set<String>,
        modelContext: ModelContext
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = normalize(trimmedName)

        guard !normalizedName.isEmpty, !trimmedGroup.isEmpty else { return false }
        guard knownNames.insert(normalizedName).inserted else { return false }

        modelContext.insert(Exercise(name: trimmedName, muscleGroup: trimmedGroup))
        return true
    }
}
