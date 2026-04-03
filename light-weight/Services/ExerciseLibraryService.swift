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
        let existingExercises = sortedExercises(modelContext: modelContext)
        let existingReferences = existingExercises.map(ExerciseReference.init)
        let libraryByName = referencesByNormalizedName(existingReferences)
        let canonicalEntries = ExerciseNameResolver.canonicalize(entries: entries, references: existingReferences)

        // Collect exercises that need targetMuscles: new exercises + existing with empty targetMuscles
        var needsTargetMuscles: [(name: String, muscleGroup: String)] = []
        var newExerciseEntries: [LogEntry] = []

        for entry in canonicalEntries {
            let normalizedName = ExerciseNameResolver.normalize(entry.exerciseName)
            if let existing = libraryByName[normalizedName] {
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
                resolvedMuscles = Dictionary(raw.map { (ExerciseNameResolver.normalize($0.key), $0.value) },
                                             uniquingKeysWith: { current, _ in current })
            } catch {
                logger.error("Failed to resolve targetMuscles: \(error)")
            }
        }

        // Insert new exercises
        var insertedNames = Set<String>()
        for entry in newExerciseEntries {
            let trimmedName = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = ExerciseNameResolver.normalize(trimmedName)
            guard !normalizedName.isEmpty, !insertedNames.contains(normalizedName) else { continue }
            insertedNames.insert(normalizedName)

            let muscles = resolvedMuscles[normalizedName] ?? []
            modelContext.insert(Exercise(
                name: trimmedName,
                muscleGroup: entry.muscleGroup,
                targetMuscles: muscles
            ))
        }

        // Backfill existing exercises with empty targetMuscles
        for exercise in existingExercises where exercise.targetMuscles.isEmpty {
            if let muscles = resolvedMuscles[ExerciseNameResolver.normalize(exercise.name)], !muscles.isEmpty {
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
        let existingExercises = sortedExercises(modelContext: modelContext)
        var result: [String: [TargetMuscle]] = [:]
        for exercise in existingExercises {
            let normalizedName = ExerciseNameResolver.normalize(exercise.name)
            if result[normalizedName] == nil {
                result[normalizedName] = exercise.targetMuscles
            }
        }
        return result
    }


    private static func sortedExercises(modelContext: ModelContext) -> [Exercise] {
        ((try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? [])
            .sorted { $0.name < $1.name }
    }

    private static func referencesByNormalizedName(_ references: [ExerciseReference]) -> [String: ExerciseReference] {
        var result: [String: ExerciseReference] = [:]

        for reference in references {
            let normalizedName = ExerciseNameResolver.normalize(reference.name)
            guard !normalizedName.isEmpty, result[normalizedName] == nil else { continue }
            result[normalizedName] = reference
        }

        return result
    }
}
