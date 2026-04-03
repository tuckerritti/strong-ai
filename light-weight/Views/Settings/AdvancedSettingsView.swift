import SwiftUI
import SwiftData

struct AdvancedSettingsView: View {
    let onReturnHome: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showingResetConfirmation = false
    @State private var resetErrorMessage: String?

    var body: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 0) {
            Text("Advanced")
                .font(.custom("SpaceGrotesk-Bold", size: 36))
                .tracking(-1.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 24) {
                    settingsSection("DATA") {
                        NavigationLink {
                            CSVImportView(onReturnHome: onReturnHome)
                        } label: {
                            HStack {
                                Text("Import Workouts (CSV)")
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    settingsSection("TOKEN COST") {
                        Toggle("Show daily API cost", isOn: $state.showTokenCost)
                            .tint(Color(hex: 0x34C759))
                    }
                    settingsSection("DANGER ZONE") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Delete all local app data and remove the iCloud backup.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)

                            Button(role: .destructive) {
                                showingResetConfirmation = true
                            } label: {
                                HStack {
                                    Text("Reset all app data")
                                    Spacer()
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .alert("Reset all data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This deletes your profile, workout history, exercise library, API key, cached workout, app settings, and iCloud backup. This can’t be undone.")
        }
        .alert("Couldn't reset data", isPresented: resetErrorPresented) {
            Button("OK", role: .cancel) {
                resetErrorMessage = nil
            }
        } message: {
            Text(resetErrorMessage ?? "Please try again.")
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.textSecondary)

            content()
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var resetErrorPresented: Binding<Bool> {
        Binding(
            get: { resetErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    resetErrorMessage = nil
                }
            }
        )
    }

    private func resetAllData() {
        do {
            try AppResetService.resetAll(modelContext: modelContext, appState: appState)
        } catch {
            resetErrorMessage = error.localizedDescription
        }
    }
}
