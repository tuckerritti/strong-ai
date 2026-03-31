import SwiftUI
import MuscleMap

struct GenderStepView: View {
    @Binding var gender: String
    var onNext: () -> Void

    private let options = ["Male", "Female"]

    private var bodyGender: BodyGender {
        gender == "Female" ? .female : .male
    }

    private var decorativeIntensities: [MuscleIntensity] {
        let highlighted: [Muscle] = [
            .chest, .upperBack, .quadriceps, .gluteal,
            .hamstring, .deltoids, .abs, .calves
        ]
        let subtle: [Muscle] = [
            .biceps, .triceps, .forearm, .trapezius
        ]
        return highlighted.map { MuscleIntensity(muscle: $0, intensity: 0.7) }
             + subtle.map { MuscleIntensity(muscle: $0, intensity: 0.3) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 3, total: 7)

            VStack(alignment: .leading, spacing: 8) {
                Text("Select your gender")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("This helps us track your muscle volume accurately.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = gender == option
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gender = option
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(selected ? Color(hex: 0x34C759) : Color.black.opacity(0.15), lineWidth: selected ? 0 : 1.5)
                                    .frame(width: 24, height: 24)
                                if selected {
                                    Circle()
                                        .fill(Color(hex: 0x34C759))
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                }
                            }
                            Text(option)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selected ? .white : Color(hex: 0x0A0A0A))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(selected ? Color(hex: 0x0A0A0A) : Color(hex: 0xF5F5F5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            if !gender.isEmpty {
                HStack(spacing: 16) {
                    BodyView(gender: bodyGender, side: .front, style: .minimal)
                        .heatmap(decorativeIntensities, colorScale: onboardingColorScale)
                        .frame(height: 200)
                        .allowsHitTesting(false)
                    BodyView(gender: bodyGender, side: .back, style: .minimal)
                        .heatmap(decorativeIntensities, colorScale: onboardingColorScale)
                        .frame(height: 200)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(gender.isEmpty ? Color(hex: 0x0A0A0A).opacity(0.4) : Color(hex: 0x0A0A0A))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(gender.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

private let onboardingColorScale = HeatmapColorScale(colors: [
    Color(hex: 0xFFB5B5),
    Color(hex: 0x34C759),
])
