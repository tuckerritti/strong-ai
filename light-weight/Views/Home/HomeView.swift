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
    ) var recentLogs: [WorkoutLog]

    @Query var profiles: [UserProfile]
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    @Environment(\.modelContext) var modelContext
    @Environment(AppState.self) var appState

    @State var todayWorkout: Workout?
    @State var isLoading = false
    @State var errorMessage: String?
    @State var healthContext: HealthContext?
    @State var exercisesExpanded = false
    @State var muscleMapExpanded = false
    @State var apiKey = ""
    @State var navigationPath = NavigationPath()

    enum Destination: Hashable {
        case library, history, settings, activeWorkout
    }

    let maxVisibleExercises = 3

    var profile: UserProfile? { profiles.first }

    var muscleMapGender: BodyGender {
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

    func generateWorkoutIfNeeded() async {
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

        if profile?.healthKitEnabled == true && HealthKitService.shared.isAvailable {
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
        } else {
            healthContext = nil
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
}
