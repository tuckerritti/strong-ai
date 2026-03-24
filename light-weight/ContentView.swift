import SwiftUI

@Observable
final class AppState {
    var chatDetent: PresentationDetent = .height(90)
    var pendingMessage: String?
    var isWorkoutActive = false
}

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        HomeView()
            .environment(appState)
    }
}
