import SwiftUI

struct ReadyStepView: View {
    let goals: Set<String>
    let experienceLevel: String
    let trainingDays: Set<Int>
    let selectedSplit: String
    let apiKeyPresent: Bool
    var onFinish: () -> Void
    @State private var startTapCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 8, total: 8)

            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x34C759).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0x34C759))
                }

                Text("You're all set")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("Here's a summary of your profile. Your first workout is ready.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            // Summary card
            VStack(spacing: 0) {
                summaryRow(label: "Goals", value: goalsText)
                divider
                summaryRow(label: "Experience", value: experienceLevel)
                divider
                summaryRow(label: "Schedule", value: "\(trainingDays.count) days / week")
                divider
                summaryRow(label: "Split", value: selectedSplit)
                divider
                HStack {
                    Text("AI")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.black.opacity(0.35))
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(apiKeyPresent ? Color(hex: 0x34C759) : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(apiKeyPresent ? "Connected" : "Not connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x0A0A0A))
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .background(Color(hex: 0xF5F5F5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.top, 28)

            Spacer()

            Button {
                startTapCount += 1
                onFinish()
            } label: {
                Text("Start Training")
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
        .sensoryFeedback(.impact, trigger: startTapCount)
    }

    private var goalsText: String {
        let short = goals.map { goal -> String in
            switch goal {
            case "Build Strength": return "Strength"
            case "Build Muscle": return "Muscle"
            case "Lose Fat": return "Fat Loss"
            case "Improve Endurance": return "Endurance"
            case "General Fitness": return "General"
            default: return goal
            }
        }
        return short.sorted().joined(separator: ", ")
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.black.opacity(0.35))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A0A0A))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}
