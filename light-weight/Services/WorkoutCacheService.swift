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
        guard let data = try? Data(contentsOf: todayFile) else { return nil }
        do {
            return try JSONDecoder().decode(Workout.self, from: data)
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
        } catch {
            logger.error("Failed to cache workout: \(error)")
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: todayFile)
    }

    private static func cleanOldFiles() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let todayURL = todayFile
        for file in files where file.lastPathComponent.hasPrefix("daily-workout-") && file != todayURL {
            try? fileManager.removeItem(at: file)
        }
    }
}
