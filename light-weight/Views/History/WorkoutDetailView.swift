import SwiftUI

struct WorkoutDetailView: View {
    let log: WorkoutLog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statsHeader
                ForEach(Array(log.entries.enumerated()), id: \.element.id) { _, entry in
                    exerciseSection(entry)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(log.workoutName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(log.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            HStack(spacing: 10) {
                StatCard(title: "DURATION", value: "\(log.durationMinutes)m")
                StatCard(title: "SETS", value: "\(log.totalSets)")
                StatCard(title: "VOLUME", value: "\(Int(log.totalVolume).formatted())")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Exercise Section

    private func exerciseSection(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.exerciseName)
                .font(.custom("SpaceGrotesk-Bold", size: 17))
                .tracking(-0.3)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)

            Text(entry.muscleGroup.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            // Column headers
            HStack(spacing: 0) {
                Text("SET")
                    .frame(width: 40, alignment: .leading)
                Text("LBS")
                    .frame(width: 72, alignment: .leading)
                Text("REPS")
                    .frame(width: 64, alignment: .leading)
                Text("RPE")
                    .frame(width: 48, alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { setIndex, set in
                    HStack(spacing: 0) {
                        Text(set.isWarmup ? "W" : "\(setIndex + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(set.isWarmup ? .textTertiary : (set.completedAt != nil ? Color.accent : .textTertiary))
                            .frame(width: 40, alignment: .leading)

                        Text(set.weight > 0 ? "\(Int(set.weight))" : "BW")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 72, alignment: .leading)

                        Text("\(set.reps)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 64, alignment: .leading)

                        Text("\(set.rpe)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 48, alignment: .leading)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                    if setIndex < entry.sets.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Card (reuse from Home — making it internal)

struct StatCard: View {
    let title: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("SpaceGrotesk-Bold", size: 28))
                .tracking(-0.5)
                .foregroundStyle(highlight ? Color.accent : .textPrimary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
