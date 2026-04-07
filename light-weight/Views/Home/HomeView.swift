import os
import SwiftUI
import SwiftData
import MuscleMap

private let logger = Logger(subsystem: "com.light-weight", category: "HomeView")

struct HomeView: View {
    @Query(
        filter: #Predicate<WorkoutLog> { $0.finishedAt != nil },
        sort: \WorkoutLog.startedAt,
        order: .reverse
    ) private var recentLogs: [WorkoutLog]

    @Query private var profiles: [UserProfile]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var todayWorkout: Workout?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var healthContext: HealthContext?
    @State private var exercisesExpanded = false
    @State private var muscleMapExpanded = false
    @State private var apiKey = ""
    @State private var navigationPath = NavigationPath()

    private enum Destination: Hashable {
        case library, history, settings, activeWorkout
    }

    private var profile: UserProfile? { profiles.first }

    private var muscleMapGender: BodyGender {
        profile?.gender == "Female" ? .female : .male
    }

    var body: some View {
        @Bindable var state = appState
        ZStack {
            NavigationStack(path: $navigationPath) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        statCards

                        if isLoading {
                            loadingSection
                        } else if let error = errorMessage {
                            errorSection(error)
                        } else if let workout = todayWorkout {
                            workoutSection(workout)
                        } else {
                            emptyWorkoutSection
                        }
                    }
                    .padding(.bottom, 100)
                }
                .onAppear {
                    apiKey = UserProfileService.loadAPIKey()
                    Task {
                        await generateWorkoutIfNeeded()
                    }
                }
                .onChange(of: profiles.count) { _, _ in
                    apiKey = UserProfileService.loadAPIKey()
                }
                .overlay {
                    if navigationPath.isEmpty {
                        ChatDrawerView(
                            selectedDetent: $state.chatDetent,
                            pendingMessage: $state.pendingMessage,
                            placeholder: "I only have 30 min today...",
                            onSend: { message, history in
                                await streamChat(message, history: history)
                            }
                        )
                    }
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .library: ExerciseLibraryView()
                    case .history: HistoryListView()
                    case .settings: SettingsView(onReturnHome: returnToHome)
                    case .activeWorkout: ActiveWorkoutView()
                    }
                }
            }

            .sensoryFeedback(.impact, trigger: appState.isWorkoutActive) { oldValue, newValue in
                oldValue == false && newValue == true
            }

            if muscleMapExpanded {
                ExpandedMuscleMapView(
                    logs: recentLogs,
                    bodyGender: muscleMapGender,
                    isPresented: $muscleMapExpanded
                )
            }
        }
    }

    private func returnToHome() {
        todayWorkout = nil
        navigationPath = NavigationPath()
    }

    // MARK: - AI Generation

    private func generateWorkoutIfNeeded() async {
        guard todayWorkout == nil else {
            logger.info("daily_workout skip reason=in_memory")
            return
        }

        if let cached = WorkoutCacheService.loadToday() {
            let canonicalWorkout = ExerciseNameResolver.canonicalize(
                workout: cached,
                references: exerciseSnapshots.map(ExerciseReference.init)
            )
            todayWorkout = canonicalWorkout
            if canonicalWorkout != cached {
                WorkoutCacheService.save(canonicalWorkout)
                logger.info("daily_workout cache_recanonicalized exercises=\(canonicalWorkout.exercises.count, privacy: .public)")
            }
            logger.info("daily_workout cache_applied exercises=\(canonicalWorkout.exercises.count, privacy: .public)")
            return
        }

        guard !apiKey.isEmpty else {
            logger.info("daily_workout skip reason=missing_api_key")
            return
        }

        isLoading = true
        errorMessage = nil
        logger.info(
            "daily_workout start recentLogs=\(recentLogs.count, privacy: .public) exercises=\(exercises.count, privacy: .public) healthkitAvailable=\(HealthKitService.shared.isAvailable, privacy: .public)"
        )

        if HealthKitService.shared.isAvailable {
            do { try await HealthKitService.shared.requestAuthorization() }
            catch { logger.error("health_context authorization_failure error=\(String(describing: error), privacy: .public)") }
            healthContext = await HealthKitService.shared.fetchRecentHealthData()
            if let healthContext {
                let metricCount = [healthContext.sleepHours, healthContext.restingHeartRate, healthContext.hrv, healthContext.activeCaloriesToday]
                    .compactMap { $0 }
                    .count
                logger.info("health_context success metrics=\(metricCount, privacy: .public)")
            } else {
                logger.info("health_context success metrics=0")
            }
        }

        do {
            let workout = try await WorkoutAIService.generateDailyWorkout(
                apiKey: apiKey,
                profile: profileSnapshot,
                recentLogs: logSnapshots,
                exercises: exerciseSnapshots,
                healthContext: healthContext
            )
            todayWorkout = workout
            WorkoutCacheService.save(workout)
            logger.info(
                "daily_workout success exercises=\(workout.exercises.count, privacy: .public) totalSets=\(workout.totalSets, privacy: .public)"
            )
        } catch {
            logger.error("daily_workout failure errorType=\(String(reflecting: type(of: error)), privacy: .public)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func streamChat(_ message: String, history: [ChatMessage]) async -> AsyncThrowingStream<ChatStreamEvent, Error>? {
        guard !apiKey.isEmpty else {
            logger.info("home_chat skip reason=missing_api_key")
            return nil
        }

        logger.info(
            "home_chat start history=\(history.count, privacy: .public) currentWorkout=\(todayWorkout != nil, privacy: .public)"
        )

        do {
            let stream = try await ChatAIService.stream(
                apiKey: apiKey,
                message: message,
                currentWorkout: todayWorkout,
                profile: profileSnapshot,
                exercises: exercises.map { ExerciseSnapshot(from: $0) },
                history: history
            )

            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await event in stream {
                            switch event {
                            case .result(let result):
                                if let workout = result.workout {
                                    todayWorkout = workout
                                    WorkoutCacheService.save(workout)
                                    errorMessage = nil
                                    logger.info(
                                        "home_chat apply_success exercises=\(workout.exercises.count, privacy: .public) totalSets=\(workout.totalSets, privacy: .public)"
                                    )
                                }
                            case .usage, .text, .applying:
                                break
                            }
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch {
                        logger.error("home_chat failure errorType=\(String(reflecting: type(of: error)), privacy: .public)")
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            logger.error("home_chat setup_failure errorType=\(String(reflecting: type(of: error)), privacy: .public)")
            return AsyncThrowingStream { continuation in
                continuation.yield(.text("Error: \(error.localizedDescription)"))
                continuation.finish()
            }
        }
    }

    // MARK: - Snapshots

    private var profileSnapshot: UserProfileSnapshot {
        UserProfileSnapshot(from: profile)
    }

    private var logSnapshots: [WorkoutLogSnapshot] {
        recentLogs.prefix(14).map { WorkoutLogSnapshot(from: $0) }
    }

    private var exerciseSnapshots: [ExerciseSnapshot] {
        exercises.map { ExerciseSnapshot(from: $0) }
    }

    // MARK: - Header

    private var headerSection: some View {
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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Stat Cards

    private var statCards: some View {
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

    private var workoutsThisWeek: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return recentLogs.filter { $0.startedAt >= startOfWeek }.count
    }

    // MARK: - Loading / Error States

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Generating your workout...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func errorSection(_ message: String) -> some View {
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

    private func workoutSection(_ workout: Workout) -> some View {
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

    private let maxVisibleExercises = 3

    private func exerciseList(_ exercises: [WorkoutExercise]) -> some View {
        let visible = exercisesExpanded ? exercises : Array(exercises.prefix(maxVisibleExercises))
        let remaining = exercises.count - maxVisibleExercises

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
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

    private func insightCallout(_ insight: String) -> some View {
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

    private func startButton(_ workout: Workout) -> some View {
        Button {
            if appState.activeViewModel == nil {
                appState.activeViewModel = ActiveWorkoutViewModel(workout: workout)
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

    private var emptyWorkoutSection: some View {
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
