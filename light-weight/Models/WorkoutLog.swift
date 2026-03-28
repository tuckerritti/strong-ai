import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "WorkoutLog")

struct TargetMuscle: Codable, Hashable, Sendable {
    var muscle: String
    var weight: Double // 0.0–1.0, proportion of volume attributed to this muscle
}

struct LogSet: Codable, Hashable, Sendable {
    var reps: Int
    var weight: Double
    var rpe: Int
    var completedAt: Date?
}

struct LogEntry: Codable, Hashable, Sendable {
    var exerciseName: String
    var muscleGroup: String
    var targetMuscles: [TargetMuscle]
    var sets: [LogSet]

    init(exerciseName: String, muscleGroup: String, targetMuscles: [TargetMuscle] = [], sets: [LogSet]) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.targetMuscles = targetMuscles
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        targetMuscles = try container.decodeIfPresent([TargetMuscle].self, forKey: .targetMuscles) ?? []
        sets = try container.decode([LogSet].self, forKey: .sets)
    }
}

extension Array where Element == LogEntry {
    func formattedProgress() -> String {
        map { entry in
            let sets = entry.sets.enumerated().map { i, set in
                if set.completedAt != nil {
                    let rpeStr = " @RPE \(set.rpe)"
                    return "  Set \(i + 1): COMPLETED - \(Int(set.weight))lbs x \(set.reps)\(rpeStr)"
                } else {
                    return "  Set \(i + 1): PLANNED - \(Int(set.weight))lbs x \(set.reps)"
                }
            }.joined(separator: "\n")
            return "\(entry.exerciseName) (\(entry.muscleGroup)):\n\(sets)"
        }.joined(separator: "\n")
    }
}

@Model
final class WorkoutLog {
    var workoutName: String
    var startedAt: Date
    var finishedAt: Date?
    var entriesData: Data

    var entries: [LogEntry] {
        get {
            do {
                return try JSONDecoder().decode([LogEntry].self, from: entriesData)
            } catch {
                logger.error("Failed to decode workout entries: \(error)")
                return []
            }
        }
        set {
            do {
                entriesData = try JSONEncoder().encode(newValue)
            } catch {
                logger.error("Failed to encode workout entries: \(error)")
            }
        }
    }

    var totalSets: Int { entries.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil }.count } }
    var durationMinutes: Int {
        let end = finishedAt ?? .now
        return Int(end.timeIntervalSince(startedAt) / 60)
    }
    var totalVolume: Double {
        entries.flatMap(\.sets)
            .filter { $0.completedAt != nil }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
    var isInProgress: Bool { finishedAt == nil }

    init(workoutName: String, entries: [LogEntry] = [], startedAt: Date = .now) {
        self.workoutName = workoutName
        self.startedAt = startedAt
        do {
            self.entriesData = try JSONEncoder().encode(entries)
        } catch {
            logger.error("Failed to encode initial workout entries: \(error)")
            self.entriesData = Data()
        }
    }
}
