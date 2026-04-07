import SwiftUI
import os

private let logger = Logger(subsystem: "com.light-weight", category: "Onboarding")

struct APIKeyStepView: View {
    @Binding var apiKey: String
    var onNext: () -> Void

    @State private var isValidating = false
    @State private var errorMessage: String?

    private var canContinue: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isValidating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 1, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Connect your AI")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("We use Claude to personalize your workouts, analyze your progress, and adapt your training in real time. Your key stays on-device.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Anthropic API Key")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                SecureField("sk-ant-api03-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color(hex: 0xF5F5F5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                } else {
                    Text("Get your key at console.anthropic.com. Stored locally using iOS Keychain.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            Button {
                validateAndContinue()
            } label: {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isValidating ? "Verifying…" : "Continue")
                        .font(.custom("SpaceGrotesk-Bold", size: 17))
                        .tracking(-0.2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canContinue ? Color(hex: 0x0A0A0A) : Color(hex: 0x0A0A0A).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func validateAndContinue() {
        isValidating = true
        errorMessage = nil

        Task {
            let startedAt = Date()
            logger.info("api_key_validation start")
            do {
                let api = ClaudeAPIService(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                _ = try await api.send(
                    operation: "validate_api_key",
                    systemPrompt: "Reply with OK",
                    userMessage: "test"
                )
                let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                logger.info("api_key_validation success durationMs=\(durationMs, privacy: .public)")
                onNext()
            } catch {
                let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                logger.error(
                    "api_key_validation failure durationMs=\(durationMs, privacy: .public) errorType=\(String(reflecting: type(of: error)), privacy: .public)"
                )
                errorMessage = "Invalid API key. Please check your key and try again."
            }
            isValidating = false
        }
    }
}
