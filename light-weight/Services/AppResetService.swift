import SwiftData
import os

private let logger = Logger(subsystem: "com.light-weight", category: "AppResetService")

@MainActor
enum AppResetService {
    static func resetAll(modelContext: ModelContext, appState: AppState) throws {
        do {
            let exerciseCount = try modelContext.fetchCount(FetchDescriptor<Exercise>())
            let workoutLogCount = try modelContext.fetchCount(FetchDescriptor<WorkoutLog>())
            let profileCount = try modelContext.fetchCount(FetchDescriptor<UserProfile>())

            logger.info(
                "app_reset start exercises=\(exerciseCount, privacy: .public) workoutLogs=\(workoutLogCount, privacy: .public) profiles=\(profileCount, privacy: .public)"
            )

            try UserProfile.deleteSavedAPIKey()
            try modelContext.delete(model: Exercise.self)
            try modelContext.delete(model: WorkoutLog.self)
            try modelContext.delete(model: UserProfile.self)
            try modelContext.save()

            WorkoutCacheService.clearAll()
            RestSound.resetSelection()
            appState.resetPersistentState()
            ICloudBackupService.deleteBackup()

            logger.info(
                "app_reset success exercises=\(exerciseCount, privacy: .public) workoutLogs=\(workoutLogCount, privacy: .public) profiles=\(profileCount, privacy: .public)"
            )
        } catch {
            logger.error("app_reset failure error=\(String(describing: error), privacy: .public)")
            throw error
        }
    }
}
