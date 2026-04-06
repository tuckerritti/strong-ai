import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.light-weight", category: "Onboarding")

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var currentStep = 0
    @State private var apiKey = ""
    @State private var gender = ""
    @State private var goals: Set<String> = []
    @State private var experienceLevel = ""
    @State private var trainingDays: Set<Int> = [0, 1, 3, 5]
    @State private var selectedSplit = "Upper / Lower Split"

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            switch currentStep {
            case 0:
                WelcomeStepView(onNext: nextStep)
            case 1:
                APIKeyStepView(apiKey: $apiKey, onNext: nextStep)
            case 2:
                HealthDataStepView(onNext: nextStep, onSkip: nextStep)
            case 3:
                GenderStepView(gender: $gender, onNext: nextStep)
            case 4:
                GoalsStepView(goals: $goals, onNext: nextStep)
            case 5:
                ExperienceStepView(experienceLevel: $experienceLevel, onNext: nextStep)
            case 6:
                ScheduleStepView(trainingDays: $trainingDays, selectedSplit: $selectedSplit, onNext: nextStep)
            case 7:
                ReadyStepView(
                    goals: goals,
                    experienceLevel: experienceLevel,
                    trainingDays: trainingDays,
                    selectedSplit: selectedSplit,
                    apiKeyPresent: !apiKey.isEmpty,
                    onFinish: completeOnboarding
                )
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    private func nextStep() {
        currentStep += 1
    }

    private func completeOnboarding() {
        let createdProfile = profile == nil
        let p = profile ?? UserProfile()
        if profile == nil {
            modelContext.insert(p)
        }

        logger.info(
            "onboarding_complete start createdProfile=\(createdProfile, privacy: .public) goals=\(goals.count, privacy: .public) trainingDays=\(trainingDays.count, privacy: .public) apiKeyPresent=\(!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, privacy: .public)"
        )

        p.goals = goals.sorted().joined(separator: ", ")
        p.gender = gender
        p.experienceLevel = experienceLevel
        p.trainingDays = encodeDays(trainingDays)
        p.schedule = "\(trainingDays.count) days per week"
        p.onboardingCompleted = true

        var didFail = false
        do {
            try UserProfile.saveAPIKey(apiKey)
        } catch {
            didFail = true
            logger.error("onboarding_complete api_key_failure error=\(String(describing: error), privacy: .public)")
        }

        do {
            try modelContext.save()
        } catch {
            didFail = true
            logger.error("onboarding_complete save_failure error=\(String(describing: error), privacy: .public)")
        }

        if !didFail {
            logger.info(
                "onboarding_complete success createdProfile=\(createdProfile, privacy: .public) apiKeyPresent=\(!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, privacy: .public)"
            )
        }
    }

    private func encodeDays(_ days: Set<Int>) -> String {
        let sorted = days.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
}
