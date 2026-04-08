import SwiftUI
import MuscleMap

struct MuscleBodyMapCard: View {
    let logs: [WorkoutLog]
    let bodyGender: BodyGender
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 4) {
            BodyView(gender: bodyGender, side: .front, style: .minimal)
                .heatmap(muscleIntensities(from: logs), colorScale: volumeColorScale)
                .frame(height: 80)
                .allowsHitTesting(false)
            Text("MUSCLE FATIGUE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { isExpanded = true }
    }
}

// MARK: - Expanded Overlay

struct ExpandedMuscleMapView: View {
    let logs: [WorkoutLog]
    let bodyGender: BodyGender
    @Binding var isPresented: Bool

    var body: some View {
        let intensities = muscleIntensities(from: logs)
        ZStack {
            Color.scrim
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                HStack {
                    Text("MUSCLE MAP")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        BodyView(gender: bodyGender, side: .front, style: .minimal)
                            .heatmap(intensities, colorScale: volumeColorScale)
                            .frame(height: 240)
                            .allowsHitTesting(false)
                        Text("FRONT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.textTertiary)
                    }

                    VStack(spacing: 8) {
                        BodyView(gender: bodyGender, side: .back, style: .minimal)
                            .heatmap(intensities, colorScale: volumeColorScale)
                            .frame(height: 240)
                            .allowsHitTesting(false)
                        Text("BACK")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(24)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.cardShadow, radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Shared Intensity Calculation

/// All muscles relevant for exercise tracking (excludes cosmetic parts like head, hands, feet).
private let exerciseMuscles: [Muscle] = Muscle.allCases.filter {
    ![Muscle.head, .hands, .feet, .knees, .ankles].contains($0)
}

/// Green (low soreness) → yellow → orange → red (high soreness).
private let volumeColorScale = HeatmapColorScale(colors: [
    Color(hex: 0x34C759),
    .yellow,
    .orange,
    .red
])

/// DOMS fatigue curve: ramps 0–12h, peaks 12–48h, decays 48–120h.
private func fatigueMultiplier(hoursSinceSet hours: Double) -> Double {
    if hours < 0 { return 0 }
    if hours < 12 { return 0.4 + 0.6 * (hours / 12.0) }
    if hours < 48 { return 1.0 }
    if hours < 120 { return 1.0 - (hours - 48.0) / 72.0 }
    return 0
}

/// Effort scaling: RPE 10 → 1.0, RPE 5 → 0.75, RPE 0 (unset) → 0.5.
private func effortMultiplier(rpe: Int) -> Double {
    0.5 + 0.5 * (Double(rpe) / 10.0)
}

private func muscleIntensities(from logs: [WorkoutLog]) -> [MuscleIntensity] {
    let now = Date.now
    var fatigueByMuscle: [Muscle: Double] = Dictionary(uniqueKeysWithValues: exerciseMuscles.map { ($0, 0.0) })

    for log in logs {
        guard log.finishedAt != nil else { continue }

        for entry in log.entries {
            for set in entry.sets {
                guard let completedAt = set.completedAt, !set.isWarmup else { continue }

                let hours = now.timeIntervalSince(completedAt) / 3600.0
                let fatigue = fatigueMultiplier(hoursSinceSet: hours)
                guard fatigue > 0 else { continue }

                let volume: Double
                switch entry.exerciseType {
                case .weightReps:
                    volume = set.weight * Double(set.reps)
                case .timed, .timedDistance:
                    volume = Double(set.durationSeconds ?? 0) * max(1, set.weight)
                }
                let effort = effortMultiplier(rpe: set.rpe)
                let contribution = volume * effort * fatigue

                for target in entry.targetMuscles {
                    if let muscle = Muscle(rawValue: target.muscle) {
                        fatigueByMuscle[muscle, default: 0] += contribution * target.weight
                    }
                }
            }
        }
    }

    let maxFatigue = fatigueByMuscle.values.max() ?? 0
    guard maxFatigue > 0 else {
        return fatigueByMuscle.map { MuscleIntensity(muscle: $0.key, intensity: 0) }
    }

    return fatigueByMuscle.map { MuscleIntensity(muscle: $0.key, intensity: $0.value / maxFatigue) }
}
