import SwiftUI

@Observable
final class AppState {
    var chatDetent: PresentationDetent = .height(90)
    var pendingMessage: String?
    var isWorkoutActive = false
    var dailyCost = TokenCost.zero
    var showTokenCost = UserDefaults.standard.bool(forKey: "showTokenCost") {
        didSet { UserDefaults.standard.set(showTokenCost, forKey: "showTokenCost") }
    }
}

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        HomeView()
            .environment(appState)
    }
}
