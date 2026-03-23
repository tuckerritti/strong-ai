import Foundation

struct Workout: Codable, Sendable {
    var name: String
    var exercises: [WorkoutExercise]
    var insight: String?

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var estimatedMinutes: Int {
        let totalRest = exercises.flatMap(\.sets).reduce(0) { $0 + $1.restSeconds }
        let workTime = totalSets * 45 // ~45s per set
        return (totalRest + workTime) / 60
    }
}

struct WorkoutExercise: Codable, Sendable {
    var name: String
    var muscleGroup: String
    var sets: [WorkoutSet]
}

struct WorkoutSet: Codable, Sendable {
    var reps: Int
    var weight: Double
    var restSeconds: Int

    init(reps: Int, weight: Double, restSeconds: Int) {
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
    }
}

// MARK: - Sample (placeholder until AI generates workouts)

extension Workout {
    static let sample = Workout(
        name: "Upper Body Push",
        exercises: [
            WorkoutExercise(name: "Bench Press", muscleGroup: "Chest", sets: [
                WorkoutSet(reps: 8, weight: 135, restSeconds: 90),
                WorkoutSet(reps: 8, weight: 135, restSeconds: 90),
                WorkoutSet(reps: 8, weight: 135, restSeconds: 90),
            ]),
            WorkoutExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: [
                WorkoutSet(reps: 10, weight: 65, restSeconds: 75),
                WorkoutSet(reps: 10, weight: 65, restSeconds: 75),
                WorkoutSet(reps: 10, weight: 65, restSeconds: 75),
            ]),
            WorkoutExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: [
                WorkoutSet(reps: 12, weight: 40, restSeconds: 60),
                WorkoutSet(reps: 12, weight: 40, restSeconds: 60),
                WorkoutSet(reps: 12, weight: 40, restSeconds: 60),
            ]),
            WorkoutExercise(name: "Tricep Pushdown", muscleGroup: "Triceps", sets: [
                WorkoutSet(reps: 15, weight: 30, restSeconds: 45),
                WorkoutSet(reps: 15, weight: 30, restSeconds: 45),
                WorkoutSet(reps: 15, weight: 30, restSeconds: 45),
            ]),
        ]
    )
}
