import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.light-weight", category: "UserProfileService")

enum UserProfileService {
    static func loadAPIKey() -> String {
        let apiKey = UserProfile.loadSavedAPIKey()
        logger.info("api_key load present=\(!apiKey.isEmpty, privacy: .public)")
        return apiKey
    }

    @discardableResult
    static func ensureProfile(existingProfile: UserProfile?, modelContext: ModelContext) -> UserProfile {
        if let existingProfile {
            logger.info("profile ensure created=false")
            return existingProfile
        }

        let profile = UserProfile()
        modelContext.insert(profile)
        logger.info("profile ensure created=true")
        return profile
    }

    static func saveAPIKey(_ apiKey: String, for profile: UserProfile?, modelContext: ModelContext) throws {
        let createdProfile = profile == nil
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info(
            "api_key save_start createdProfile=\(createdProfile, privacy: .public) empty=\(trimmedKey.isEmpty, privacy: .public)"
        )
        do {
            _ = ensureProfile(existingProfile: profile, modelContext: modelContext)
            try UserProfile.saveAPIKey(apiKey)

            if createdProfile {
                try modelContext.save()
            }
            logger.info("api_key save_success createdProfile=\(createdProfile, privacy: .public)")
        } catch {
            logger.error("api_key save_failure createdProfile=\(createdProfile, privacy: .public) error=\(String(describing: error), privacy: .public)")
            throw error
        }
    }
}
