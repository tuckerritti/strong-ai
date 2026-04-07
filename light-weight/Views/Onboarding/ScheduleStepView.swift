import SwiftUI

struct ScheduleStepView: View {
    @Binding var trainingDays: Set<Int>
    @Binding var selectedSplit: String
    var onNext: () -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 6, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("How often can you train?")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color(hex: 0x0A0A0A))

                Text("We'll build your split around this. You can always change it later.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            // Day count display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(trainingDays.count)")
                    .font(.custom("SpaceGrotesk-Bold", size: 72))
                    .tracking(-2)
                    .foregroundStyle(Color(hex: 0x0A0A0A))
                Text("days / week")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)

            // Day circles
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let selected = trainingDays.contains(index)
                    Button {
                        if selected {
                            trainingDays.remove(index)
                        } else {
                            trainingDays.insert(index)
                        }
                        updateSplit()
                    } label: {
                        Text(dayLabels[index])
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? .white : Color.black.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .background(selected ? Color(hex: 0x0A0A0A) : Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            // Recommended split
            if !trainingDays.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECOMMENDED SPLIT")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.black.opacity(0.35))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(splitRecommendation.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x0A0A0A))
                            Spacer()
                            Text("Best match")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: 0x34C759))
                        }
                        Text(splitRecommendation.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.black.opacity(0.35))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(Color(hex: 0xF5F5F5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(trainingDays.isEmpty ? Color(hex: 0x0A0A0A).opacity(0.4) : Color(hex: 0x0A0A0A))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(trainingDays.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear { updateSplit() }
    }

    private var splitRecommendation: (name: String, description: String) {
        switch trainingDays.count {
        case 1:
            return ("Full Body", "One comprehensive session targeting all major muscle groups.")
        case 2:
            return ("Full Body", "Hit every muscle group each session. Best for 2-day schedules.")
        case 3:
            return ("Push / Pull / Legs", "One day each for push, pull, and legs. Classic 3-day split.")
        case 4:
            return ("Upper / Lower Split", "2 upper days, 2 lower days with a rest day between each pair. Ideal for strength and muscle at 4 days.")
        case 5:
            return ("Upper / Lower + Accessories", "2 upper, 2 lower, plus a day for weak points and arms.")
        case 6, 7:
            return ("Push / Pull / Legs x2", "Each muscle group trained twice per week. High frequency for experienced lifters.")
        default:
            return ("Full Body", "Hit every muscle group each session.")
        }
    }

    private func updateSplit() {
        selectedSplit = splitRecommendation.name
    }
}
