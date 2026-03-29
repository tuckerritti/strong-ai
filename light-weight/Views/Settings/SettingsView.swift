import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey = ""
    @State private var apiKeyError: String?
    @State private var selectedSounds: Set<RestSound> = RestSound.selected
    @Environment(AppState.self) private var appState

    @State private var soundPreview = RestSoundService()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.custom("SpaceGrotesk-Bold", size: 36))
                    .tracking(-1.4)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        settingsSection("API KEY") {
                            VStack(alignment: .leading, spacing: 8) {
                                SecureField("sk-ant-...", text: apiKeyBinding)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .privacySensitive()

                                if let apiKeyError {
                                    Text(apiKeyError)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        settingsSection("GOALS") {
                            TextField("e.g. Build muscle, lose fat", text: binding(\.goals), axis: .vertical)
                                .lineLimit(3...6)
                        }
                        settingsSection("SCHEDULE") {
                            TextField("e.g. 4 days/week, Mon/Tue/Thu/Fri", text: binding(\.schedule), axis: .vertical)
                                .lineLimit(2...4)
                        }
                        settingsSection("EQUIPMENT") {
                            TextField("e.g. Full gym, home dumbbells only", text: binding(\.equipment), axis: .vertical)
                                .lineLimit(2...4)
                        }
                        settingsSection("INJURIES / LIMITATIONS") {
                            TextField("e.g. Bad left shoulder, avoid overhead", text: binding(\.injuries), axis: .vertical)
                                .lineLimit(2...4)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REST TIMER SOUNDS")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(Color.textSecondary)

                            VStack(spacing: 0) {
                                ForEach(RestSound.allCases) { sound in
                                    Button {
                                        if selectedSounds.contains(sound) {
                                            if selectedSounds.count > 1 {
                                                selectedSounds.remove(sound)
                                            }
                                        } else {
                                            selectedSounds.insert(sound)
                                            soundPreview.previewSound(sound)
                                        }
                                        RestSound.selected = selectedSounds
                                    } label: {
                                        HStack {
                                            Text(sound.displayName)
                                                .foregroundStyle(Color.textPrimary)
                                            Spacer()
                                            if selectedSounds.contains(sound) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(Color.accent)
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if sound != RestSound.allCases.last {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        settingsSection("TOKEN COST") {
                            Toggle("Show daily API cost", isOn: $state.showTokenCost)
                                .tint(Color(hex: 0x34C759))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                syncProfileState()
            }
            .onChange(of: profiles.count) { _, _ in
                syncProfileState()
            }
            .onDisappear {
                ICloudBackupService.backupAll(modelContext: modelContext)
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

    private func binding(_ keyPath: ReferenceWritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? "" },
            set: { profile?[keyPath: keyPath] = $0 }
        )
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { apiKey },
            set: { newValue in
                apiKey = newValue
                persistAPIKey(newValue)
            }
        )
    }

    private func syncProfileState() {
        if profiles.isEmpty {
            UserProfileService.ensureProfile(existingProfile: profile, modelContext: modelContext)
        }

        apiKey = UserProfileService.loadAPIKey()
        apiKeyError = nil
    }

    private func persistAPIKey(_ newValue: String) {
        do {
            try UserProfileService.saveAPIKey(newValue, for: profile, modelContext: modelContext)
            apiKeyError = nil
        } catch {
            apiKeyError = error.localizedDescription
        }
    }
}
