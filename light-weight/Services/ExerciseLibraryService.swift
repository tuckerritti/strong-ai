import Foundation
import SwiftData

enum ExerciseLibraryService {
    static func persist(
        logEntries: [LogEntry],
        existingExercises: [Exercise],
        modelContext: ModelContext
    ) {
        var knownNames = Set(existingExercises.map { normalize($0.name) })

        for entry in logEntries {
            let trimmedName = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedGroup = entry.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = normalize(trimmedName)

            guard !normalizedName.isEmpty, !trimmedGroup.isEmpty else { continue }
            guard knownNames.insert(normalizedName).inserted else { continue }

            modelContext.insert(Exercise(name: trimmedName, muscleGroup: trimmedGroup, targetMuscles: entry.targetMuscles))
        }
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
