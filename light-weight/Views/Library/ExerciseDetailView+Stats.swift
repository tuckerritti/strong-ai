import Charts
import MuscleMap
import SwiftUI

extension ExerciseDetailView {

    struct TargetMuscleDisplay: Identifiable {
        let id: String
        let name: String
        let percentage: Int
        let weight: Double
        let mappedMuscle: Muscle?
    }

    // MARK: - Computed Data

    var exerciseLogs: [(date: Date, entry: LogEntry)] {
        let normalizedName = ExerciseNameResolver.normalize(exercise.name)
        return allLogs.compactMap { log -> (date: Date, entry: LogEntry)? in
            guard let entry = log.entries.first(where: {
                ExerciseNameResolver.normalize($0.exerciseName) == normalizedName
            }) else {
                return nil
            }
            guard entry.sets.contains(where: { $0.completedAt != nil }) else { return nil }
            return (log.startedAt, entry)
        }
    }

    var targetMuscleRows: [TargetMuscleDisplay] {
        exercise.targetMuscles
            .reduce(into: [String: Double]()) { result, target in
                guard target.weight > 0 else { return }
                result[target.muscle, default: 0] += target.weight
            }
            .map { muscle, weight in
                let mappedMuscle = Muscle(rawValue: muscle)
                return TargetMuscleDisplay(
                    id: muscle,
                    name: mappedMuscle?.displayName ?? humanizedMuscleName(muscle),
                    percentage: Int((weight * 100).rounded()),
                    weight: weight,
                    mappedMuscle: mappedMuscle
                )
            }
            .sorted {
                if $0.weight == $1.weight {
                    return $0.name < $1.name
                }
                return $0.weight > $1.weight
            }
    }

    var targetMuscleMapIntensities: [MuscleIntensity] {
        let mappedRows = targetMuscleRows.compactMap { row -> (Muscle, Double)? in
            guard let muscle = row.mappedMuscle else { return nil }
            return (muscle, row.weight)
        }
        let maxWeight = mappedRows.map { $0.1 }.max() ?? 0

        guard maxWeight > 0 else { return [] }

        return mappedRows.map { muscle, weight in
            MuscleIntensity(muscle: muscle, intensity: weight / maxWeight)
        }
    }

    // MARK: - Stats

    var bestWeight: Double {
        exerciseLogs.flatMap { $0.entry.sets }.filter { $0.completedAt != nil && !$0.isWarmup }.map(\.weight).max() ?? 0
    }

    var sessionCount: Int { exerciseLogs.count }

    var totalSets: Int {
        exerciseLogs.reduce(0) { $0 + $1.entry.sets.filter { $0.completedAt != nil && !$0.isWarmup }.count }
    }

    var weightChange: Double {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
        let recentLogs = exerciseLogs.filter { $0.date >= threeMonthsAgo }
        guard let oldest = recentLogs.last, let newest = recentLogs.first else { return 0 }
        let oldMax = oldest.entry.sets.filter { $0.completedAt != nil && !$0.isWarmup }.map(\.weight).max() ?? 0
        let newMax = newest.entry.sets.filter { $0.completedAt != nil && !$0.isWarmup }.map(\.weight).max() ?? 0
        return newMax - oldMax
    }

    @ViewBuilder
    var statsSection: some View {
        if !exerciseLogs.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Stats")
                    .font(.custom("SpaceGrotesk-Bold", size: 18))
                    .tracking(-0.18)
                    .foregroundStyle(Color.textHeading)

                HStack(spacing: 0) {
                    exerciseStat(value: bestWeight.formattedWeight, label: "Best (lbs)")
                    exerciseStat(value: "\(sessionCount)", label: "Sessions")
                    exerciseStat(value: "\(totalSets)", label: "Total Sets")
                    let change = weightChange
                    exerciseStat(
                        value: "\(change >= 0 ? "+" : "")\(change.formattedWeight)",
                        label: "lbs / 3 mo",
                        color: Color.accentAlt
                    )
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)
        }
    }

    func exerciseStat(value: String, label: String, color: Color = Color.textHeading) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom("SpaceGrotesk-Bold", size: 26))
                .tracking(-0.52)
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.66)
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weight Progression Chart

    var chartDataPoints: [(date: Date, weight: Double)] {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
        return exerciseLogs
            .filter { $0.date >= threeMonthsAgo }
            .compactMap { log in
                let maxWeight = log.entry.sets.filter { $0.completedAt != nil && !$0.isWarmup }.map(\.weight).max()
                guard let weight = maxWeight else { return nil }
                return (log.date, weight)
            }
            .reversed()
    }

    @ViewBuilder
    var progressChartSection: some View {
        if chartDataPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Weight Progression")
                        .font(.custom("SpaceGrotesk-Bold", size: 18))
                        .tracking(-0.18)
                        .foregroundStyle(Color.textHeading)
                    Spacer()
                    Text("3 months")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                }

                Chart {
                    ForEach(chartDataPoints, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentAlt.opacity(0.15), Color.accentAlt.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color.accentAlt)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color.accentAlt)
                        .symbolSize(30)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                        AxisGridLine()
                            .foregroundStyle(Color.appSurfaceAlt)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .frame(height: 148)
                .padding(16)
                .background(Color.appSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Recent History

    @ViewBuilder
    var recentHistorySection: some View {
        if !exerciseLogs.isEmpty {
            let recentEntries = Array(exerciseLogs.prefix(4))

            VStack(alignment: .leading, spacing: 0) {
                Text("Recent History")
                    .font(.custom("SpaceGrotesk-Bold", size: 18))
                    .tracking(-0.18)
                    .foregroundStyle(Color.textHeading)
                    .padding(.bottom, 12)

                ForEach(Array(recentEntries.enumerated()), id: \.offset) { index, log in
                    let completedMaxWeight = log.entry.sets
                        .filter { $0.completedAt != nil && !$0.isWarmup }
                        .map(\.weight)
                        .max() ?? 0

                    historyRow(date: log.date, entry: log.entry, isPR: index == 0 && bestWeight == completedMaxWeight)

                    if index < recentEntries.count - 1 {
                        Divider()
                            .background(Color.appSurfaceAlt)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
        }
    }

    func historyRow(date: Date, entry: LogEntry, isPR: Bool) -> some View {
        let completedSets = entry.sets.filter { $0.completedAt != nil && !$0.isWarmup }
        let maxWeight = completedSets.map(\.weight).max() ?? 0
        let totalReps = completedSets.reduce(0) { $0 + $1.reps }

        return HStack {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                    Text(date.formatted(.dateTime.day()))
                        .font(.custom("SpaceGrotesk-Bold", size: 20))
                        .foregroundStyle(Color.textHeading)
                }
                .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedSets.count) sets · \(totalReps) reps")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textHeading)
                    Text("\(maxWeight.formattedWeight) lbs · \(entry.muscleGroup)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            if isPR {
                Text("PR")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentAlt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    func humanizedMuscleName(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "-", with: " ")
            .localizedCapitalized
    }
}

let targetMuscleColorScale = HeatmapColorScale(colors: [
    Color(hex: 0xE5F7EB),
    Color(hex: 0xA8E0B8),
    Color(hex: 0x5AC878),
    Color(hex: 0x1E7C3F)
])
