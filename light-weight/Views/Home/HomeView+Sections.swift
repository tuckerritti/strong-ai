import SwiftUI
import MuscleMap

extension HomeView {

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                    .font(.system(size: 13, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if appState.showTokenCost, appState.dailyCost.estimatedCost > 0 {
                    Text("~$\(appState.dailyCost.estimatedCost, specifier: "%.4f")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            HStack(alignment: .center) {
                Text(greeting)
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-1.0)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 0) {
                    NavigationLink(value: Destination.library) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Exercise Library")
                    NavigationLink(value: Destination.history) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Workout History")
                    NavigationLink(value: Destination.settings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Stat Cards

    var statCards: some View {
        HStack(spacing: 10) {
            StatCard(title: "THIS WEEK", value: "\(workoutsThisWeek)")
            StatCard(title: "STREAK", value: "\(recentLogs.streak)", highlight: recentLogs.streak > 0)
            MuscleBodyMapCard(
                logs: recentLogs,
                bodyGender: muscleMapGender,
                isExpanded: $muscleMapExpanded
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    var workoutsThisWeek: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return recentLogs.filter { $0.startedAt >= startOfWeek }.count
    }

    // MARK: - Loading / Error States

    var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Generating your workout...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            if apiKey.isEmpty {
                Text("Add your Claude API key in Settings to get AI-generated workouts.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task { await generateWorkoutIfNeeded() }
                }
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Workout Section

    func workoutSection(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's Workout")
                .font(.custom("SpaceGrotesk-Bold", size: 20))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 28)

            HStack(spacing: 8) {
                Text(workout.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text("\(workout.totalSets) sets · ~\(workout.estimatedMinutes) min")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            exerciseList(workout.exercises)

            if let insight = workout.insight {
                insightCallout(insight)
            }

            startButton(workout)
        }
    }

    func exerciseList(_ exercises: [WorkoutExercise]) -> some View {
        let visible = exercisesExpanded ? exercises : Array(exercises.prefix(maxVisibleExercises))
        let remaining = exercises.count - maxVisibleExercises

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if exercise.supersetGroupId != nil {
                        Text("SS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accent)
                    }
                    Spacer()
                    Text("\(exercise.sets.count) sets · \(exercise.sets.reduce(0) { $0 + $1.reps }) reps")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            if remaining > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        exercisesExpanded.toggle()
                    }
                } label: {
                    Text(exercisesExpanded ? "Show less" : "+\(remaining) more")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    func insightCallout(_ insight: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13))
                .foregroundStyle(Color.insightIcon)
                .padding(.top, 1)
            Text(insight)
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(Color.insightText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.insightBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    func startButton(_ workout: Workout) -> some View {
        Button {
            if appState.activeViewModel == nil {
                appState.activeViewModel = ActiveWorkoutViewModel(
                    workout: workout,
                    appState: appState,
                    onCost: { [appState] cost in appState.recordCost(cost) }
                )
            }
            navigationPath.append(Destination.activeWorkout)
        } label: {
            Text(appState.activeViewModel != nil ? "Resume Workout" : "Start Workout")
                .font(.custom("SpaceGrotesk-Bold", size: 17))
                .tracking(-0.2)
                .foregroundStyle(Color.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.buttonPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    var emptyWorkoutSection: some View {
        VStack(spacing: 12) {
            if apiKey.isEmpty {
                Text("Add your API key in Settings to get started.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No workout planned")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Ask the AI to generate one.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
