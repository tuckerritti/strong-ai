import SwiftUI
import SwiftData
import os

private let appStateLogger = Logger(subsystem: "com.light-weight", category: "AppState")
private let contentViewLogger = Logger(subsystem: "com.light-weight", category: "ContentView")

@Observable
final class AppState {
    private var shouldPersistState = true

    var chatDetent: PresentationDetent = .height(90)
    var pendingMessage: String?
    var activeViewModel: ActiveWorkoutViewModel?
    var isWorkoutActive = false
    var showTokenCost = UserDefaults.standard.bool(forKey: "showTokenCost") {
        didSet {
            guard shouldPersistState else { return }
            UserDefaults.standard.set(showTokenCost, forKey: "showTokenCost")
        }
    }
    var showRestTimer: Bool = {
        if UserDefaults.standard.object(forKey: "showRestTimer") == nil { return true }
        return UserDefaults.standard.bool(forKey: "showRestTimer")
    }() {
        didSet {
            guard shouldPersistState else { return }
            UserDefaults.standard.set(showRestTimer, forKey: "showRestTimer")
        }
    }

    var dailyCost: TokenCost {
        didSet {
            guard shouldPersistState else { return }
            saveDailyCost()
        }
    }

    init() {
        dailyCost = Self.loadDailyCost()
        appStateLogger.info("daily_cost load inputTokens=\(self.dailyCost.inputTokens, privacy: .public) outputTokens=\(self.dailyCost.outputTokens, privacy: .public)")
    }

    func recordCost(_ cost: TokenCost) {
        resetIfNewDay()
        dailyCost = dailyCost + cost
        appStateLogger.info(
            "token_cost record inputTokens=\(cost.inputTokens, privacy: .public) outputTokens=\(cost.outputTokens, privacy: .public) totalInputTokens=\(self.dailyCost.inputTokens, privacy: .public) totalOutputTokens=\(self.dailyCost.outputTokens, privacy: .public)"
        )
    }

    func resetPersistentState() {
        let defaults = UserDefaults.standard
        appStateLogger.info("persistent_state reset_start")
        shouldPersistState = false
        defer { shouldPersistState = true }

        defaults.removeObject(forKey: "showTokenCost")
        defaults.removeObject(forKey: "showRestTimer")
        defaults.removeObject(forKey: "dailyCostInput")
        defaults.removeObject(forKey: "dailyCostOutput")
        defaults.removeObject(forKey: "dailyCostDate")

        chatDetent = .height(90)
        pendingMessage = nil
        activeViewModel = nil
        isWorkoutActive = false
        showTokenCost = false
        showRestTimer = true
        dailyCost = .zero
        appStateLogger.info("persistent_state reset_success")
    }

    private func resetIfNewDay() {
        let storedDate = UserDefaults.standard.string(forKey: "dailyCostDate") ?? ""
        if storedDate != Self.todayString() {
            dailyCost = .zero
            appStateLogger.info("daily_cost reset_new_day hadStoredDate=\(!storedDate.isEmpty, privacy: .public)")
        }
    }

    private func saveDailyCost() {
        UserDefaults.standard.set(dailyCost.inputTokens, forKey: "dailyCostInput")
        UserDefaults.standard.set(dailyCost.outputTokens, forKey: "dailyCostOutput")
        UserDefaults.standard.set(Self.todayString(), forKey: "dailyCostDate")
    }

    private static func loadDailyCost() -> TokenCost {
        let storedDate = UserDefaults.standard.string(forKey: "dailyCostDate") ?? ""
        guard storedDate == todayString() else { return .zero }
        return TokenCost(
            inputTokens: UserDefaults.standard.integer(forKey: "dailyCostInput"),
            outputTokens: UserDefaults.standard.integer(forKey: "dailyCostOutput")
        )
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

struct ContentView: View {
    @State private var appState = AppState()
    @State private var isRestoring = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]

    private var needsOnboarding: Bool {
        guard let profile = profiles.first else { return true }
        return !profile.onboardingCompleted
    }

    private var currentRoute: String {
        if isRestoring { return "restoring" }
        return needsOnboarding ? "onboarding" : "home"
    }

    var body: some View {
        Group {
            if isRestoring {
                Color(hex: 0x0A0A0A)
                    .ignoresSafeArea()
                    .task {
                        contentViewLogger.info("restore start")
                        await ICloudBackupService.restoreIfNeeded(modelContext: modelContext)
                        isRestoring = false
                        contentViewLogger.info("restore success")
                    }
            } else if needsOnboarding {
                OnboardingView()
                    .environment(appState)
            } else {
                HomeView()
                    .environment(appState)
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .background {
                            contentViewLogger.info("scene_phase background profiles=\(profiles.count, privacy: .public)")
                            ICloudBackupService.backupAll(modelContext: modelContext)
                        }
                    }
            }
        }
        .task(id: currentRoute) {
            let onboardingCompleted = profiles.first?.onboardingCompleted ?? false
            contentViewLogger.info(
                "route state route=\(currentRoute, privacy: .public) profiles=\(profiles.count, privacy: .public) onboardingCompleted=\(onboardingCompleted, privacy: .public)"
            )
        }
    }
}
