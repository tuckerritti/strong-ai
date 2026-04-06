import Foundation

struct Workout: Codable, Sendable, Hashable {
    var name: String
    var exercises: [WorkoutExercise]
    var insight: String?

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count } }
    var estimatedMinutes: Int {
        let totalRest = exercises.flatMap(\.sets).reduce(0) { $0 + $1.restSeconds }
        let workTime = totalSets * 45 // ~45s per set
        return (totalRest + workTime) / 60
    }
}

struct WorkoutExercise: Codable, Sendable, Hashable {
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
        let rawName = try container.decode(String.self, forKey: .name)
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmedName.isEmpty ? "Unknown Exercise" : trimmedName
        let rawGroup = try container.decode(String.self, forKey: .muscleGroup)
        let trimmedGroup = rawGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        muscleGroup = trimmedGroup.isEmpty ? "Other" : trimmedGroup
        targetMuscles = try container.decodeIfPresent([TargetMuscle].self, forKey: .targetMuscles) ?? []
        sets = try container.decode([WorkoutSet].self, forKey: .sets)
    }
}

struct WorkoutSet: Codable, Sendable, Hashable {
    var reps: Int
    var weight: Double
    var restSeconds: Int
    var targetRpe: Int?
    var isWarmup: Bool

    init(reps: Int, weight: Double, restSeconds: Int, targetRpe: Int? = nil, isWarmup: Bool = false) {
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.targetRpe = targetRpe
        self.isWarmup = isWarmup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reps = max(1, min(100, try container.decode(Int.self, forKey: .reps)))
        weight = max(0, min(2000, try container.decode(Double.self, forKey: .weight)))
        restSeconds = max(10, min(600, try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90))
        targetRpe = try container.decodeIfPresent(Int.self, forKey: .targetRpe).map { max(1, min(10, $0)) }
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
    }
}