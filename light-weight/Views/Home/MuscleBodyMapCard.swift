import SwiftUI
import MuscleMap

struct MuscleBodyMapCard: View {
    let logs: [WorkoutLog]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 4) {
            BodyView(gender: .male, side: .front, style: .minimal)
                .heatmap(muscleIntensities(from: logs), colorScale: volumeColorScale)
                .frame(height: 80)
                .allowsHitTesting(false)
            Text("VOLUME")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.black.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color(hex: 0xF5F5F5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { isExpanded = true }
    }
}

// MARK: - Expanded Overlay

struct ExpandedMuscleMapView: View {
    let logs: [WorkoutLog]
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                HStack {
                    Text("MUSCLE MAP")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.black.opacity(0.35))
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.black.opacity(0.3))
                    }
                }

                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        BodyView(gender: .male, side: .front, style: .minimal)
                            .heatmap(muscleIntensities(from: logs), colorScale: volumeColorScale)
                            .frame(height: 240)
                            .allowsHitTesting(false)
                        Text("FRONT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.black.opacity(0.3))
                    }

                    VStack(spacing: 8) {
                        BodyView(gender: .male, side: .back, style: .minimal)
                            .heatmap(muscleIntensities(from: logs), colorScale: volumeColorScale)
                            .frame(height: 240)
                            .allowsHitTesting(false)
                        Text("BACK")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.black.opacity(0.3))
                    }
                }
            }
            .padding(24)
            .background(Color(hex: 0xF5F5F5))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Shared Intensity Calculation

/// All muscles relevant for exercise tracking (excludes cosmetic parts like head, hands, feet).
private let exerciseMuscles: [Muscle] = Muscle.allCases.filter {
    ![Muscle.head, .hands, .feet, .knees, .ankles].contains($0)
}

/// Green (low volume) → yellow → orange → red (high volume).
private let volumeColorScale = HeatmapColorScale(colors: [
    Color(hex: 0x34C759),
    .yellow,
    .orange,
    .red
])

private func muscleIntensities(from logs: [WorkoutLog]) -> [MuscleIntensity] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    var volumeByMuscle: [Muscle: Double] = Dictionary(uniqueKeysWithValues: exerciseMuscles.map { ($0, 0.0) })

    for log in logs {
        guard let finishedAt = log.finishedAt else { continue }
        let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: finishedAt), to: today).day ?? 999
        guard daysSince <= 6 else { continue }

        for entry in log.entries {
            let entryVolume = entry.sets
                .filter { $0.completedAt != nil }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            guard entryVolume > 0 else { continue }

            for target in entry.targetMuscles {
                if let muscle = Muscle(rawValue: target.muscle) {
                    volumeByMuscle[muscle, default: 0] += entryVolume * target.weight
                }
            }
        }
    }

    let maxVolume = volumeByMuscle.values.max() ?? 0
    guard maxVolume > 0 else {
        return volumeByMuscle.map { MuscleIntensity(muscle: $0.key, intensity: 0) }
    }

    return volumeByMuscle.map { MuscleIntensity(muscle: $0.key, intensity: $0.value / maxVolume) }
}
