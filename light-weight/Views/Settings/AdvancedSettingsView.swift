import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState

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
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
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
}
