import Foundation
import os

private let logger = Logger(subsystem: "com.light-weight", category: "WorkoutCacheService")

enum WorkoutCacheService {
    private static let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private static var todayFile: URL {
        let dateString = ISO8601DateFormatter.string(from: .now, timeZone: .current, formatOptions: .withFullDate)
        return directory.appendingPathComponent("daily-workout-\(dateString).json")
    }

    static func loadToday() -> Workout? {
        guard let data = try? Data(contentsOf: todayFile) else {
            logger.info("workout_cache load_miss")
            return nil
        }
        do {
            let workout = try JSONDecoder().decode(Workout.self, from: data)
            let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
            logger.info(
                "workout_cache load_hit exercises=\(workout.exercises.count, privacy: .public) totalSets=\(totalSets, privacy: .public)"
            )
            return workout
        } catch {
            logger.error("Failed to decode cached workout: \(error)")
            return nil
        }
    }

    static func save(_ workout: Workout) {
        do {
            let data = try JSONEncoder().encode(workout)
            try data.write(to: todayFile, options: .atomic)
            cleanOldFiles()
            let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
            logger.info(
                "workout_cache save_success exercises=\(workout.exercises.count, privacy: .public) totalSets=\(totalSets, privacy: .public)"
            )
        } catch {
            logger.error("Failed to cache workout: \(error)")
        }
    }

    static func clearAll() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }

        var removedCount = 0
        for file in files where file.lastPathComponent.hasPrefix("daily-workout-") {
            do {
                try fileManager.removeItem(at: file)
                removedCount += 1
            } catch {
                logger.error("workout_cache clear_failure error=\(String(describing: error), privacy: .public)")
            }
        }
        logger.info("workout_cache clear_success removed=\(removedCount, privacy: .public)")
    }

    private static func cleanOldFiles() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let todayURL = todayFile
        var removedCount = 0
        for file in files where file.lastPathComponent.hasPrefix("daily-workout-") && file != todayURL {
            do {
                try fileManager.removeItem(at: file)
                removedCount += 1
            } catch {
                logger.error("workout_cache cleanup_failure error=\(String(describing: error), privacy: .public)")
            }
        }
        if removedCount > 0 {
            logger.info("workout_cache cleanup_success removed=\(removedCount, privacy: .public)")
        }
    }
}
