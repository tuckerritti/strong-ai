import SwiftUI

struct GoalsStepView: View {
    @Binding var goals: Set<String>
    var onNext: () -> Void

    private let goalOptions: [(title: String, subtitle: String)] = [
        ("Build Strength", "Increase your 1RM on compound lifts"),
        ("Build Muscle", "Hypertrophy-focused volume and progressive overload"),
        ("Lose Fat", "Higher intensity, circuits, and caloric burn"),
        ("Improve Endurance", "Conditioning, supersets, and cardio integration"),
        ("General Fitness", "Balanced programming across all areas"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 4, total: 7)

            VStack(alignment: .leading, spacing: 8) {
                Text("What are your goals?")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("Pick all that apply. This shapes your programming.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(goalOptions, id: \.title) { option in
                    let selected = goals.contains(option.title)
                    Button {
                        if selected {
                            goals.remove(option.title)
                        } else {
                            goals.insert(option.title)
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(selected ? .white : Color(hex: 0x0A0A0A))
                                Text(option.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(selected ? Color.white.opacity(0.6) : Color.black.opacity(0.35))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
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

            Button(action: onNext) {
                Text("Continue")
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(goals.isEmpty ? Color(hex: 0x0A0A0A).opacity(0.4) : Color(hex: 0x0A0A0A))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(goals.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
