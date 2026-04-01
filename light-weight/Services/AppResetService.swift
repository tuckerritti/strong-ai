import SwiftData

@MainActor
enum AppResetService {
    static func resetAll(modelContext: ModelContext, appState: AppState) throws {
        try UserProfile.deleteSavedAPIKey()
        try modelContext.delete(model: Exercise.self)
        try modelContext.delete(model: WorkoutLog.self)
        try modelContext.delete(model: UserProfile.self)
        try modelContext.save()

        WorkoutCacheService.clearAll()
        RestSound.resetSelection()
        appState.resetPersistentState()
        ICloudBackupService.deleteBackup()
    }
}
