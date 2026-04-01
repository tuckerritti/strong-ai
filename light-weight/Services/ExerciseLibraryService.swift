import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.light-weight", category: "ExerciseLibrary")

enum ExerciseLibraryService {

    /// Persists new exercises from a completed workout and resolves their targetMuscles via AI.
    /// Also backfills targetMuscles on any existing library exercises that are missing them.
    static func resolveAndPersistNewExercises(
        entries: [LogEntry],
        apiKey: String,
        modelContext: ModelContext
    ) async {
        let existingExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let libraryByName = Dictionary(uniqueKeysWithValues: existingExercises.map { (normalize($0.name), $0) })

        // Collect exercises that need targetMuscles: new exercises + existing with empty targetMuscles
        var needsTargetMuscles: [(name: String, muscleGroup: String)] = []
        var newExerciseEntries: [LogEntry] = []

        for entry in entries {
            let normalized = normalize(entry.exerciseName)
            if let existing = libraryByName[normalized] {
                if existing.targetMuscles.isEmpty {
                    needsTargetMuscles.append((name: existing.name, muscleGroup: existing.muscleGroup))
                }
            } else {
                newExerciseEntries.append(entry)
                needsTargetMuscles.append((name: entry.exerciseName, muscleGroup: entry.muscleGroup))
            }
        }

        // Batch-resolve targetMuscles for all exercises that need them
        var resolvedMuscles: [String: [TargetMuscle]] = [:]
        if !needsTargetMuscles.isEmpty && !apiKey.isEmpty {
            do {
                let raw = try await WorkoutAIService.generateTargetMuscles(
                    apiKey: apiKey,
                    exercises: needsTargetMuscles
                )
                resolvedMuscles = Dictionary(uniqueKeysWithValues: raw.map { (normalize($0.key), $0.value) })
            } catch {
                logger.error("Failed to resolve targetMuscles: \(error)")
            }
        }

        // Insert new exercises
        var insertedNames = Set<String>()
        for entry in newExerciseEntries {
            let trimmedName = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalize(trimmedName)
            guard !normalized.isEmpty, !insertedNames.contains(normalized) else { continue }
            insertedNames.insert(normalized)

            let muscles = resolvedMuscles[normalized] ?? []
            modelContext.insert(Exercise(
                name: trimmedName,
                muscleGroup: entry.muscleGroup,
                targetMuscles: muscles
            ))
        }

        // Backfill existing exercises with empty targetMuscles
        for exercise in existingExercises where exercise.targetMuscles.isEmpty {
            if let muscles = resolvedMuscles[normalize(exercise.name)], !muscles.isEmpty {
                exercise.targetMuscles = muscles
            }
        }
    }

    /// Returns resolved targetMuscles for the given entries, using the library as source of truth.
    /// Used to backfill a WorkoutLog's entries after exercise resolution.
    static func resolvedTargetMuscles(
        for entries: [LogEntry],
        modelContext: ModelContext
    ) -> [String: [TargetMuscle]] {
        let existingExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        var result: [String: [TargetMuscle]] = [:]
        for exercise in existingExercises {
            result[normalize(exercise.name)] = exercise.targetMuscles
        }
        return result
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
