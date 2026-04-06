import Foundation
import os

private let logger = Logger(subsystem: "com.light-weight", category: "ActiveWorkoutCache")

struct ActiveWorkoutState: Codable, Hashable {
    var workoutName: String
    var workoutExercises: [WorkoutExercise]
    var entries: [LogEntry]
    var startedAt: Date
}

enum ActiveWorkoutCacheService {
    private static let file = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("active-workout.json")

    static func load() -> ActiveWorkoutState? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        do {
            let state = try JSONDecoder().decode(ActiveWorkoutState.self, from: data)
            // Discard stale sessions older than 24 hours
            guard Date().timeIntervalSince(state.startedAt) < 24 * 60 * 60 else {
                clear()
                return nil
            }
            return state
        } catch {
            logger.error("Failed to decode active workout: \(error)")
            return nil
        }
    }

    static func save(_ state: ActiveWorkoutState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: file, options: .atomic)
        } catch {
            logger.error("Failed to save active workout: \(error)")
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
