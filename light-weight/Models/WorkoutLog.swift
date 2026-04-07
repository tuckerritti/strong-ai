import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "WorkoutLog")

struct TargetMuscle: Codable, Hashable, Sendable {
    var muscle: String
    var weight: Double // 0.0–1.0, proportion of volume attributed to this muscle
}

struct LogSet: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var reps: Int
    var weight: Double
    var rpe: Int
    var completedAt: Date?
    var isWarmup: Bool

    init(reps: Int, weight: Double, rpe: Int, completedAt: Date? = nil, isWarmup: Bool = false) {
        self.id = UUID()
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.completedAt = completedAt
        self.isWarmup = isWarmup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        rpe = try container.decode(Int.self, forKey: .rpe)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
    }

    static func == (lhs: LogSet, rhs: LogSet) -> Bool {
        lhs.reps == rhs.reps && lhs.weight == rhs.weight && lhs.rpe == rhs.rpe && lhs.completedAt == rhs.completedAt && lhs.isWarmup == rhs.isWarmup
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(reps)
        hasher.combine(weight)
        hasher.combine(rpe)
        hasher.combine(completedAt)
        hasher.combine(isWarmup)
    }
}

struct LogEntry: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var exerciseName: String
    var muscleGroup: String
    var targetMuscles: [TargetMuscle]
    var sets: [LogSet]

    init(exerciseName: String, muscleGroup: String, targetMuscles: [TargetMuscle] = [], sets: [LogSet]) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.targetMuscles = targetMuscles
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        muscleGroup = try container.decode(String.self, forKey: .muscleGroup)
        targetMuscles = try container.decodeIfPresent([TargetMuscle].self, forKey: .targetMuscles) ?? []
        sets = try container.decode([LogSet].self, forKey: .sets)
    }

    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.exerciseName == rhs.exerciseName && lhs.muscleGroup == rhs.muscleGroup && lhs.sets == rhs.sets
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(exerciseName)
        hasher.combine(muscleGroup)
        hasher.combine(sets)
    }
}

extension Array where Element == LogEntry {
    func formattedProgress() -> String {
        map { entry in
            var workingSetCount = 0
            let sets = entry.sets.map { set in
                let label: String
                if set.isWarmup {
                    label = "Warmup"
                } else {
                    workingSetCount += 1
                    label = "Set \(workingSetCount)"
                }
                if set.completedAt != nil {
                    let rpeStr = " @RPE \(set.rpe)"
                    return "  \(label): COMPLETED - \(set.weight.formattedWeight)lbs x \(set.reps)\(rpeStr)"
                } else {
                    return "  \(label): PLANNED - \(set.weight.formattedWeight)lbs x \(set.reps)"
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

    var totalSets: Int { entries.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil && !$0.isWarmup }.count } }
    var durationMinutes: Int {
        let end = finishedAt ?? .now
        return Int(end.timeIntervalSince(startedAt) / 60)
    }
    var totalVolume: Double {
        entries.flatMap(\.sets)
            .filter { $0.completedAt != nil && !$0.isWarmup }
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

extension Array where Element: WorkoutLog {
    var streak: Int {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: .now)
        var count = 0
        let logDates = Set(map { calendar.startOfDay(for: $0.startedAt) })

        if !logDates.contains(currentDate),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) {
            currentDate = yesterday
        }

        while logDates.contains(currentDate) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        return count
    }
}
