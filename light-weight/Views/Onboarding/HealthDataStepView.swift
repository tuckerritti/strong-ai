import SwiftUI

struct HealthDataStepView: View {
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 2, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Sync your health data")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("We read sleep, heart rate, and recovery data to tailor each workout to how your body is doing today.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 8) {
                infoCard(
                    icon: "moon.zzz",
                    iconColor: Color(hex: 0x30B0C7),
                    title: "Sleep",
                    subtitle: "Duration and quality to adjust volume"
                )
                infoCard(
                    icon: "heart.fill",
                    iconColor: Color(hex: 0xE74C3C),
                    title: "Heart Rate",
                    subtitle: "Resting HR for recovery scoring"
                )
                infoCard(
                    icon: "flame.fill",
                    iconColor: Color(hex: 0x34C759),
                    title: "Activity",
                    subtitle: "Steps and energy to gauge readiness"
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        if HealthKitService.shared.isAvailable {
                            try? await HealthKitService.shared.requestAuthorization()
                        }
                        onNext()
                    }
                } label: {
                    Text("Enable HealthKit")
                        .font(.custom("SpaceGrotesk-Bold", size: 17))
                        .tracking(-0.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: 0x0A0A0A))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.black.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func infoCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0A0A0A))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.35))
            }
            Spacer()
        }
        .padding(16)
        .background(Color(hex: 0xF5F5F5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
