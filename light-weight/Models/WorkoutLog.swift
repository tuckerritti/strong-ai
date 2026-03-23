import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "WorkoutLog")

struct LogSet: Codable, Hashable, Sendable {
    var reps: Int
    var weight: Double
    var rpe: Int?
    var completedAt: Date?
}

struct LogEntry: Codable, Hashable, Sendable {
    var exerciseName: String
    var muscleGroup: String
    var sets: [LogSet]
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
