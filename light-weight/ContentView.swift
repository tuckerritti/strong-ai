import SwiftUI
import SwiftData

@Observable
final class AppState {
    static var shared: AppState!

    private var shouldPersistState = true

    var chatDetent: PresentationDetent = .height(90)
    var pendingMessage: String?
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
    }

    func recordCost(_ cost: TokenCost) {
        resetIfNewDay()
        dailyCost = dailyCost + cost
    }

    func resetPersistentState() {
        let defaults = UserDefaults.standard
        shouldPersistState = false
        defer { shouldPersistState = true }

        defaults.removeObject(forKey: "showTokenCost")
        defaults.removeObject(forKey: "showRestTimer")
        defaults.removeObject(forKey: "dailyCostInput")
        defaults.removeObject(forKey: "dailyCostOutput")
        defaults.removeObject(forKey: "dailyCostDate")

        chatDetent = .height(90)
        pendingMessage = nil
        isWorkoutActive = false
        showTokenCost = false
        showRestTimer = true
        dailyCost = .zero
    }

    private func resetIfNewDay() {
        let storedDate = UserDefaults.standard.string(forKey: "dailyCostDate") ?? ""
        if storedDate != Self.todayString() {
            dailyCost = .zero
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

    var body: some View {
        if isRestoring {
            Color(hex: 0x0A0A0A)
                .ignoresSafeArea()
                .task {
                    #if !DEBUG
                    await ICloudBackupService.restoreIfNeeded(modelContext: modelContext)
                    #endif
                    isRestoring = false
                }
        } else if needsOnboarding {
            OnboardingView()
                .environment(appState)
        } else {
            HomeView()
                .environment(appState)
                .onAppear { AppState.shared = appState }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        ICloudBackupService.backupAll(modelContext: modelContext)
                    }
                }
        }
    }
}
