import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "ICloudBackup")

// MARK: - Backup Data Structs

struct AppBackup: Codable {
    var version: Int = 1
    var createdAt: Date
    var exercises: [ExerciseBackup]
    var workoutLogs: [WorkoutLogBackup]
    var userProfile: UserProfileBackup?
}

struct ExerciseBackup: Codable {
    var name: String
    var muscleGroup: String
    var exerciseDescription: String?
    var instructions: [String]
    var targetMuscles: [TargetMuscle]
}

struct WorkoutLogBackup: Codable {
    var workoutName: String
    var startedAt: Date
    var finishedAt: Date?
    var entries: [LogEntry]
}

struct UserProfileBackup: Codable {
    var goals: String
    var schedule: String
    var equipment: String
    var injuries: String
}

// MARK: - Service

enum ICloudBackupService {

    private static let backupFileName = "backup.json"

    private static var documentsURL: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return container.appending(path: "Documents")
    }

    // MARK: - Backup

    static func backupAll(modelContext: ModelContext) {
        guard let documentsURL else {
            logger.info("iCloud not available, skipping backup")
            return
        }

        do {
            let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
            let logs = try modelContext.fetch(FetchDescriptor<WorkoutLog>(
                predicate: #Predicate { $0.finishedAt != nil }
            ))
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())

            let backup = AppBackup(
                createdAt: .now,
                exercises: exercises.map {
                    ExerciseBackup(
                        name: $0.name,
                        muscleGroup: $0.muscleGroup,
                        exerciseDescription: $0.exerciseDescription,
                        instructions: $0.instructions,
                        targetMuscles: $0.targetMuscles
                    )
                },
                workoutLogs: logs.map {
                    WorkoutLogBackup(
                        workoutName: $0.workoutName,
                        startedAt: $0.startedAt,
                        finishedAt: $0.finishedAt,
                        entries: $0.entries
                    )
                },
                userProfile: profiles.first.map {
                    UserProfileBackup(
                        goals: $0.goals,
                        schedule: $0.schedule,
                        equipment: $0.equipment,
                        injuries: $0.injuries
                    )
                }
            )

            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(backup)
            try data.write(to: documentsURL.appending(path: backupFileName), options: .atomic)

            logger.info("Backup written: \(exercises.count) exercises, \(logs.count) logs")
        } catch {
            logger.error("Backup failed: \(error)")
        }
    }

    // MARK: - Restore

    static func restoreIfNeeded(modelContext: ModelContext) async {
        let exerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let logCount = (try? modelContext.fetchCount(FetchDescriptor<WorkoutLog>())) ?? 0
        guard exerciseCount == 0 && logCount == 0 else { return }

        guard let documentsURL else {
            logger.info("iCloud not available, skipping restore")
            return
        }

        let fileURL = documentsURL.appending(path: backupFileName)

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

            // Wait for iCloud to finish downloading (up to 30s)
            for _ in 0..<60 {
                let status = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus
                if status == .current { break }
                try? await Task.sleep(for: .milliseconds(500))
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(AppBackup.self, from: data)

            for ex in backup.exercises {
                modelContext.insert(Exercise(
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    exerciseDescription: ex.exerciseDescription,
                    instructions: ex.instructions,
                    targetMuscles: ex.targetMuscles
                ))
            }

            for log in backup.workoutLogs {
                let workoutLog = WorkoutLog(
                    workoutName: log.workoutName,
                    entries: log.entries,
                    startedAt: log.startedAt
                )
                workoutLog.finishedAt = log.finishedAt
                modelContext.insert(workoutLog)
            }

            if let p = backup.userProfile {
                let existing = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
                let target = existing ?? UserProfile()
                target.goals = p.goals
                target.schedule = p.schedule
                target.equipment = p.equipment
                target.injuries = p.injuries
                if existing == nil {
                    modelContext.insert(target)
                }
            }

            logger.info("Restored from backup: \(backup.exercises.count) exercises, \(backup.workoutLogs.count) logs")
        } catch {
            logger.error("Restore failed: \(error)")
        }
    }
}
