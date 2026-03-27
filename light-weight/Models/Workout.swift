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
    var targetMuscles: [TargetMuscle]
    var sets: [WorkoutSet]

    init(name: String, muscleGroup: String, targetMuscles: [TargetMuscle] = [], sets: [WorkoutSet]) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.targetMuscles = targetMuscles
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        targetMuscles = try container.decodeIfPresent([TargetMuscle].self, forKey: .targetMuscles) ?? []
        sets = try container.decode([WorkoutSet].self, forKey: .sets)
    }
}

struct WorkoutSet: Codable, Sendable {
    var reps: Int
    var weight: Double
    var restSeconds: Int
    var targetRpe: Int?

    init(reps: Int, weight: Double, restSeconds: Int, targetRpe: Int? = nil) {
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.targetRpe = targetRpe
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        targetRpe = try container.decodeIfPresent(Int.self, forKey: .targetRpe)
    }
}