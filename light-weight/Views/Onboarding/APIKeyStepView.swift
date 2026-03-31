import SwiftUI

struct APIKeyStepView: View {
    @Binding var apiKey: String
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 1, total: 7)

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

                Text("Get your key at console.anthropic.com. Stored locally using iOS Keychain.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0x0A0A0A))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
