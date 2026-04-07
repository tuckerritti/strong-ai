import Foundation

struct ExerciseReference {
    var name: String
    var muscleGroup: String
    var targetMuscles: [TargetMuscle]

    init(name: String, muscleGroup: String, targetMuscles: [TargetMuscle] = []) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.targetMuscles = targetMuscles
    }

    init(_ exercise: Exercise) {
        self.init(
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            targetMuscles: exercise.targetMuscles
        )
    }

    init(_ exercise: ExerciseSnapshot) {
        self.init(
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            targetMuscles: exercise.targetMuscles
        )
    }

    init(_ exercise: WorkoutExercise) {
        self.init(
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            targetMuscles: exercise.targetMuscles
        )
    }

    init(_ entry: LogEntry) {
        self.init(
            name: entry.exerciseName,
            muscleGroup: entry.muscleGroup,
            targetMuscles: entry.targetMuscles
        )
    }
}

enum ExerciseNameResolver {
    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func canonicalize(workout: Workout, references: [ExerciseReference]) -> Workout {
        Workout(
            name: workout.name,
            exercises: canonicalize(exercises: workout.exercises, references: references),
            insight: workout.insight
        )
    }

    static func canonicalize(entries: [LogEntry], references: [ExerciseReference]) -> [LogEntry] {
        let canonicalByName = canonicalReferencesByNormalizedName(references)
        var canonicalEntries: [LogEntry] = []
        var indicesByNormalizedName: [String: Int] = [:]

        for entry in entries {
            let canonicalEntry = canonicalEntry(from: entry, canonicalByName: canonicalByName)
            let normalizedName = normalize(canonicalEntry.exerciseName)

            guard !normalizedName.isEmpty else {
                canonicalEntries.append(canonicalEntry)
                continue
            }

            if let index = indicesByNormalizedName[normalizedName] {
                canonicalEntries[index].sets.append(contentsOf: canonicalEntry.sets)
                if canonicalEntries[index].targetMuscles.isEmpty && !canonicalEntry.targetMuscles.isEmpty {
                    canonicalEntries[index].targetMuscles = canonicalEntry.targetMuscles
                }
            } else {
                indicesByNormalizedName[normalizedName] = canonicalEntries.count
                canonicalEntries.append(canonicalEntry)
            }
        }

        return canonicalEntries
    }

    private static func canonicalize(exercises: [WorkoutExercise], references: [ExerciseReference]) -> [WorkoutExercise] {
        let canonicalByName = canonicalReferencesByNormalizedName(references)
        var canonicalExercises: [WorkoutExercise] = []
        var indicesByNormalizedName: [String: Int] = [:]

        for exercise in exercises {
            let canonicalExercise = canonicalExercise(from: exercise, canonicalByName: canonicalByName)
            let normalizedName = normalize(canonicalExercise.name)

            guard !normalizedName.isEmpty else {
                canonicalExercises.append(canonicalExercise)
                continue
            }

            if let index = indicesByNormalizedName[normalizedName] {
                canonicalExercises[index].sets.append(contentsOf: canonicalExercise.sets)
                if canonicalExercises[index].targetMuscles.isEmpty && !canonicalExercise.targetMuscles.isEmpty {
                    canonicalExercises[index].targetMuscles = canonicalExercise.targetMuscles
                }
            } else {
                indicesByNormalizedName[normalizedName] = canonicalExercises.count
                canonicalExercises.append(canonicalExercise)
            }
        }

        return canonicalExercises
    }

    private static func canonicalReferencesByNormalizedName(_ references: [ExerciseReference]) -> [String: ExerciseReference] {
        var result: [String: ExerciseReference] = [:]

        for reference in references {
            let normalizedName = normalize(reference.name)
            guard !normalizedName.isEmpty, result[normalizedName] == nil else { continue }
            result[normalizedName] = reference
        }

        return result
    }

    private static func canonicalExercise(
        from exercise: WorkoutExercise,
        canonicalByName: [String: ExerciseReference]
    ) -> WorkoutExercise {
        let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = exercise.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = normalize(trimmedName)

        guard let reference = canonicalByName[normalizedName] else {
            return WorkoutExercise(
                name: trimmedName,
                muscleGroup: trimmedGroup,
                targetMuscles: exercise.targetMuscles,
                sets: exercise.sets,
                supersetGroupId: exercise.supersetGroupId
            )
        }

        return WorkoutExercise(
            name: reference.name,
            muscleGroup: reference.muscleGroup,
            targetMuscles: reference.targetMuscles.isEmpty ? exercise.targetMuscles : reference.targetMuscles,
            sets: exercise.sets,
            supersetGroupId: exercise.supersetGroupId
        )
    }

    private static func canonicalEntry(
        from entry: LogEntry,
        canonicalByName: [String: ExerciseReference]
    ) -> LogEntry {
        let trimmedName = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = entry.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = normalize(trimmedName)

        guard let reference = canonicalByName[normalizedName] else {
            return LogEntry(
                exerciseName: trimmedName,
                muscleGroup: trimmedGroup,
                targetMuscles: entry.targetMuscles,
                sets: entry.sets,
                supersetGroupId: entry.supersetGroupId
            )
        }

        return LogEntry(
            exerciseName: reference.name,
            muscleGroup: reference.muscleGroup,
            targetMuscles: reference.targetMuscles.isEmpty ? entry.targetMuscles : reference.targetMuscles,
            sets: entry.sets,
            supersetGroupId: entry.supersetGroupId
        )
    }
}
