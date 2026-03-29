import SwiftUI

@Observable
final class AppState {
    static var shared: AppState!

    var chatDetent: PresentationDetent = .height(90)
    var pendingMessage: String?
    var isWorkoutActive = false
    var showTokenCost = UserDefaults.standard.bool(forKey: "showTokenCost") {
        didSet { UserDefaults.standard.set(showTokenCost, forKey: "showTokenCost") }
    }

    var dailyCost: TokenCost {
        didSet { saveDailyCost() }
    }

    init() {
        dailyCost = Self.loadDailyCost()
    }

    func recordCost(_ cost: TokenCost) {
        resetIfNewDay()
        dailyCost = dailyCost + cost
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

    var body: some View {
        HomeView()
            .environment(appState)
            .onAppear { AppState.shared = appState }
    }
}
