import SwiftUI

struct ExperienceStepView: View {
    @Binding var experienceLevel: String
    var onNext: () -> Void

    private let options: [(title: String, subtitle: String)] = [
        ("Beginner", "New to lifting or less than 6 months"),
        ("Intermediate", "1-3 years of consistent training"),
        ("Advanced", "3+ years, comfortable with periodization"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 5, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your experience level")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color.textPrimary)

                Text("This helps us choose the right exercises and progression pace for you.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(options, id: \.title) { option in
                    let selected = experienceLevel == option.title
                    Button {
                        experienceLevel = option.title
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
                                            Circle()
                                                .fill(.white)
                                                .frame(width: 8, height: 8)
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
                    .background(experienceLevel.isEmpty ? Color.buttonPrimary.opacity(0.4) : Color.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(experienceLevel.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
