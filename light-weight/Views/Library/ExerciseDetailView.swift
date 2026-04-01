import Charts
import MuscleMap
import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Query(
        filter: #Predicate<WorkoutLog> { $0.finishedAt != nil },
        sort: \WorkoutLog.startedAt,
        order: .reverse
    ) private var allLogs: [WorkoutLog]
    @Query private var profiles: [UserProfile]

    private struct TargetMuscleDisplay: Identifiable {
        let id: String
        let name: String
        let percentage: Int
        let weight: Double
        let mappedMuscle: Muscle?
    }

    private var exerciseLogs: [(date: Date, entry: LogEntry)] {
        allLogs.compactMap { log in
            guard let entry = log.entries.first(where: { $0.exerciseName == exercise.name }) else { return nil }
            guard entry.sets.contains(where: { $0.completedAt != nil }) else { return nil }
            return (log.startedAt, entry)
        }
    }

    private var bodyGender: BodyGender {
        guard let gender = profiles.first?.gender else { return .male }
        return gender.localizedCaseInsensitiveCompare("Female") == .orderedSame ? .female : .male
    }

    private var targetMuscleRows: [TargetMuscleDisplay] {
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

    private var targetMuscleMapIntensities: [MuscleIntensity] {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleArea
                exerciseImage
                descriptionSection
                targetMusclesSection
                howToSection
                statsSection
                progressChartSection
                recentHistorySection
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Title Area

    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.custom("SpaceGrotesk-Bold", size: 28))
                .tracking(-0.56)
                .foregroundStyle(Color.textHeading)
            Text(exercise.muscleGroup.uppercased())
                .font(.system(size: 13, weight: .medium))
                .tracking(0.52)
                .foregroundStyle(Color.accentAlt)
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Exercise Image

    private var exerciseImage: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appSurfaceSubtle)
            .frame(height: 200)
            .overlay {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.textMuted.opacity(0.5))
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = exercise.exerciseDescription, !description.isEmpty {
            Text(description)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(7)
                .foregroundStyle(Color.textBody)
                .padding(.top, 20)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Target Muscles

    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Muscles")
                .font(.custom("SpaceGrotesk-Bold", size: 18))
                .tracking(-0.18)
                .foregroundStyle(Color.textHeading)

            if targetMuscleRows.isEmpty {
                Text("Target muscles aren't available for this exercise yet.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Darker green = more emphasis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)

                    HStack(spacing: 20) {
                        targetMuscleMapView(side: .front, title: "FRONT")
                        targetMuscleMapView(side: .back, title: "BACK")
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(targetMuscleRows.enumerated()), id: \.element.id) { index, row in
                            HStack {
                                Text(row.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textHeading)

                                Spacer()

                                Text("\(row.percentage)%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.vertical, 10)

                            if index < targetMuscleRows.count - 1 {
                                Divider()
                                    .background(Color.appSurfaceAlt)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.appSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
    }

    private func targetMuscleMapView(side: BodySide, title: String) -> some View {
        VStack(spacing: 8) {
            BodyView(gender: bodyGender, side: side, style: .minimal)
                .heatmap(targetMuscleMapIntensities, colorScale: targetMuscleColorScale)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .allowsHitTesting(false)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - How to Perform

    @ViewBuilder
    private var howToSection: some View {
        let steps = exercise.instructions
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Perform")
                    .font(.custom("SpaceGrotesk-Bold", size: 18))
                    .tracking(-0.18)
                    .foregroundStyle(Color.textHeading)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.buttonPrimaryText)
                            .frame(width: 24, height: 24)
                            .background(Color.textHeading)
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(6)
                            .foregroundStyle(Color.textBody)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Stats

    private var bestWeight: Double {
        exerciseLogs.flatMap { $0.entry.sets }.filter { $0.completedAt != nil }.map(\.weight).max() ?? 0
    }

    private var sessionCount: Int { exerciseLogs.count }

    private var totalSets: Int {
        exerciseLogs.reduce(0) { $0 + $1.entry.sets.filter { $0.completedAt != nil }.count }
    }

    private var weightChange: Double {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
        let recentLogs = exerciseLogs.filter { $0.date >= threeMonthsAgo }
        guard let oldest = recentLogs.last, let newest = recentLogs.first else { return 0 }
        let oldMax = oldest.entry.sets.filter { $0.completedAt != nil }.map(\.weight).max() ?? 0
        let newMax = newest.entry.sets.filter { $0.completedAt != nil }.map(\.weight).max() ?? 0
        return newMax - oldMax
    }

    @ViewBuilder
    private var statsSection: some View {
        if !exerciseLogs.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Stats")
                    .font(.custom("SpaceGrotesk-Bold", size: 18))
                    .tracking(-0.18)
                    .foregroundStyle(Color.textHeading)

                HStack(spacing: 0) {
                    exerciseStat(value: "\(Int(bestWeight))", label: "Best (lbs)")
                    exerciseStat(value: "\(sessionCount)", label: "Sessions")
                    exerciseStat(value: "\(totalSets)", label: "Total Sets")
                    let change = weightChange
                    exerciseStat(
                        value: "\(change >= 0 ? "+" : "")\(Int(change))",
                        label: "lbs / 3 mo",
                        color: Color.accentAlt
                    )
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)
        }
    }

    private func exerciseStat(value: String, label: String, color: Color = Color.textHeading) -> some View {
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

    private var chartDataPoints: [(date: Date, weight: Double)] {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
        return exerciseLogs
            .filter { $0.date >= threeMonthsAgo }
            .compactMap { log in
                let maxWeight = log.entry.sets.filter { $0.completedAt != nil }.map(\.weight).max()
                guard let weight = maxWeight else { return nil }
                return (log.date, weight)
            }
            .reversed()
    }

    @ViewBuilder
    private var progressChartSection: some View {
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
    private var recentHistorySection: some View {
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
                        .filter { $0.completedAt != nil }
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

    private func historyRow(date: Date, entry: LogEntry, isPR: Bool) -> some View {
        let completedSets = entry.sets.filter { $0.completedAt != nil }
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
                    Text("\(Int(maxWeight)) lbs · \(entry.muscleGroup)")
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

    private func humanizedMuscleName(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "-", with: " ")
            .localizedCapitalized
    }
}

private let targetMuscleColorScale = HeatmapColorScale(colors: [
    Color(hex: 0xE5F7EB),
    Color(hex: 0xA8E0B8),
    Color(hex: 0x5AC878),
    Color(hex: 0x1E7C3F)
])
