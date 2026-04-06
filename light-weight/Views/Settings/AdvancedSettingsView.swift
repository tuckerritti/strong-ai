import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.light-weight", category: "AdvancedSettings")

struct AdvancedSettingsView: View {
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
        logger.info("advanced_reset start")
        do {
            try AppResetService.resetAll(modelContext: modelContext, appState: appState)
            logger.info("advanced_reset success")
        } catch {
            resetErrorMessage = error.localizedDescription
            logger.error("advanced_reset failure error=\(String(describing: error), privacy: .public)")
        }
    }
}
