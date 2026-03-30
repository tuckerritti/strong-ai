import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \WorkoutLog.startedAt, order: .reverse) private var logs: [WorkoutLog]

    private var completedLogs: [WorkoutLog] { logs.filter { $0.finishedAt != nil } }

    private var thisWeekLogs: [WorkoutLog] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return completedLogs.filter { $0.startedAt >= start }
    }

    private var lastWeekLogs: [WorkoutLog] {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? .now
        return completedLogs.filter { $0.startedAt >= lastWeekStart && $0.startedAt < thisWeekStart }
    }

    private var olderLogs: [WorkoutLog] {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? .now
        return completedLogs.filter { $0.startedAt < lastWeekStart }
    }

    private var olderLogsByMonth: [(String, [WorkoutLog])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: olderLogs) { log -> Date in
            calendar.dateInterval(of: .month, for: log.startedAt)?.start ?? log.startedAt
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (formatter.string(from: $0.key).uppercased(), $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("History")
                    .font(.custom("SpaceGrotesk-Bold", size: 36))
                    .tracking(-1.4)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                statsRow
                logSection("THIS WEEK", logs: thisWeekLogs)
                logSection("LAST WEEK", logs: lastWeekLogs)
                ForEach(olderLogsByMonth, id: \.0) { title, logs in
                    logSection(title, logs: logs)
                }
            }
            .padding(.bottom, 100)
        }
        .overlay {
            if completedLogs.isEmpty {
                ContentUnavailableView("No Workouts Yet", systemImage: "figure.strengthtraining.traditional", description: Text("Completed workouts will appear here."))
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatCard(title: "WORKOUTS", value: "\(completedLogs.count)")
            StatCard(title: "THIS MONTH", value: "\(logsThisMonth)")
            StatCard(title: "STREAK", value: "\(completedLogs.streak)", highlight: completedLogs.streak > 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var logsThisMonth: Int {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        return completedLogs.filter { $0.startedAt >= start }.count
    }

    // MARK: - Log Section

    @ViewBuilder
    private func logSection(_ title: String, logs: [WorkoutLog]) -> some View {
        if !logs.isEmpty {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(logs) { log in
                    logRow(log)
                    if log.id != logs.last?.id {
                        Divider().padding(.leading, 90)
                    }
                }
            }
        }
    }

    private func logRow(_ log: WorkoutLog) -> some View {
        NavigationLink(destination: WorkoutDetailView(log: log)) {
        HStack(spacing: 16) {
            // Date column
            VStack(spacing: 0) {
                Text(log.startedAt.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text(log.startedAt.formatted(.dateTime.day()))
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.5)
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(width: 50)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(log.workoutName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                if log.isInProgress {
                    Text("In progress...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Text("\(log.totalSets) sets · \(log.durationMinutes) min · \(Int(log.totalVolume).formatted()) lbs")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
