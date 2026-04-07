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
            OnboardingProgressBar(current: 4, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("What are your goals?")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color.textPrimary)

                Text("Pick all that apply. This shapes your programming.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
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
                                    .stroke(selected ? Color.accent : Color.divider, lineWidth: selected ? 0 : 1.5)
                                    .frame(width: 24, height: 24)
                                if selected {
                                    Circle()
                                        .fill(Color.accent)
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
                                    .foregroundStyle(selected ? Color.buttonPrimaryText : Color.textPrimary)
                                Text(option.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(selected ? Color.white.opacity(0.6) : Color.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background(selected ? Color.buttonPrimary : Color.appSurface)
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
                    .foregroundStyle(Color.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(goals.isEmpty ? Color.buttonPrimary.opacity(0.4) : Color.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(goals.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .sensoryFeedback(.selection, trigger: goals)
    }
}
