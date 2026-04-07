import os
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "ActiveWorkout")

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(
        filter: #Predicate<WorkoutLog> { $0.finishedAt != nil },
        sort: \WorkoutLog.startedAt,
        order: .reverse
    ) private var recentLogs: [WorkoutLog]

    @Query private var profiles: [UserProfile]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showingDebrief = false
    @State private var finishedLog: WorkoutLog?
    @State private var apiKey = ""
    @State private var debriefRecentLogs: [WorkoutLogSnapshot] = []
    @State private var chatDetent: PresentationDetent = .height(90)
    @State private var chatPendingMessage: String?
    @State private var showChat = false
    @State private var workoutFinishedCount = 0

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if let viewModel = appState.activeViewModel {
                activeWorkoutContent(viewModel: viewModel)
            } else {
                Color.clear
                    .onAppear {
                        dismiss()
                    }
            }
        }
    }

    private func activeWorkoutContent(viewModel: ActiveWorkoutViewModel) -> some View {
        VStack(spacing: 0) {
            timerSection(viewModel: viewModel)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection(viewModel: viewModel)

                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { exerciseIndex, entry in
                        exerciseSection(viewModel: viewModel, exerciseIndex: exerciseIndex, entry: entry)
                    }

                    cancelButton(viewModel: viewModel)
                }
                .padding(.bottom, 120)
            }
        }
        .sensoryFeedback(.success, trigger: workoutFinishedCount)
        .sensoryFeedback(.warning, trigger: viewModel.timerService.expiredCount)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        })
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showChat = false
                    appState.isWorkoutActive = false
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    showNativeAlert(
                        title: "Finish Workout?",
                        message: "Save your workout with \(viewModel.completedSets) sets completed?",
                        confirmTitle: "Finish",
                        isDestructive: false
                    ) { finishWorkout(viewModel: viewModel) }
                }
                .disabled(viewModel.completedSets == 0)
            }
        }
        .overlay {
            if !apiKey.isEmpty && showChat {
                ChatDrawerView(
                    selectedDetent: $chatDetent,
                    pendingMessage: $chatPendingMessage,
                    placeholder: "Add more tricep work...",
                    workoutName: viewModel.workoutName,
                    elapsedTime: viewModel.elapsedFormatted,
                    exerciseProgress: "\(viewModel.completedSets) of \(viewModel.totalSets) sets",
                    onSend: { message, history in
                        await streamMidWorkoutChat(viewModel: viewModel, message, history: history)
                    }
                )
            }
        }
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(isPresented: $showingDebrief, onDismiss: {
            finishedLog = nil
            debriefRecentLogs = []
            dismiss()
            DispatchQueue.main.async {
                appState.activeViewModel = nil
            }
        }) {
            if let log = finishedLog {
                WorkoutDebriefView(
                    log: log,
                    recentLogs: debriefRecentLogs,
                    profile: UserProfileSnapshot(
                        goals: profile?.goals ?? "",
                        schedule: profile?.schedule ?? "",
                        equipment: profile?.equipment ?? "",
                        injuries: profile?.injuries ?? ""
                    ),
                    apiKey: apiKey
                )
            }
        }
        .onAppear {
            appState.isWorkoutActive = true
            appState.chatDetent = .height(90)
            apiKey = UserProfileService.loadAPIKey()
            viewModel.apiKey = apiKey
            viewModel.start()
            viewModel.resumeTimer()
            logger.info(
                "workout_session start exercises=\(viewModel.totalExercises, privacy: .public) totalSets=\(viewModel.totalSets, privacy: .public) apiKeyPresent=\(!apiKey.isEmpty, privacy: .public)"
            )
            if appState.showRestTimer {
                viewModel.timerService.requestPermission()
            }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                showChat = true
            }
        }
        .onDisappear {
            appState.activeViewModel?.pauseTimer()
            appState.isWorkoutActive = false
            logger.info("workout_session disappear completedSets=\(viewModel.completedSets, privacy: .public)")
        }
    }

    // MARK: - Header

    private func headerSection(viewModel: ActiveWorkoutViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.workoutName)
                .font(.custom("SpaceGrotesk-Bold", size: 28))
                .tracking(-0.84)
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: 12) {
                Text(viewModel.elapsedFormatted)
                    .font(.custom("SpaceGrotesk-Bold", size: 15))
                    .foregroundStyle(Color.accent)
                    .contentTransition(.numericText())
                Text("\(viewModel.completedExercises) of \(viewModel.totalExercises) exercises")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                if appState.showTokenCost, appState.dailyCost.estimatedCost > 0 {
                    Text("~$\(appState.dailyCost.estimatedCost, specifier: "%.4f")")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    // MARK: - Timer

    @ViewBuilder
    private func timerSection(viewModel: ActiveWorkoutViewModel) -> some View {
        if appState.showRestTimer && viewModel.timerService.isRunning {
            RestTimerView(timerService: viewModel.timerService)
                .padding(.horizontal, 20)
        }
    }

    private func exerciseHeader(entry: LogEntry) -> some View {
        HStack {
            Text(entry.exerciseName)
                .font(.custom("SpaceGrotesk-Bold", size: 18))
                .tracking(-0.18)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(entry.muscleGroup.uppercased())
                .font(.system(size: 12, weight: .medium))
                .tracking(0.72)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Exercise Section

    private func exerciseSection(viewModel: ActiveWorkoutViewModel, exerciseIndex: Int, entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let normalizedEntryName = ExerciseNameResolver.normalize(entry.exerciseName)
            Group {
                if let exercise = exercises.first(where: {
                    ExerciseNameResolver.normalize($0.name) == normalizedEntryName
                }) {
                    NavigationLink(value: exercise) {
                        exerciseHeader(entry: entry)
                    }
                    .buttonStyle(.plain)
                } else {
                    exerciseHeader(entry: entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 40, alignment: .leading)
                Text("LBS")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("RPE")
                    .frame(width: 48, alignment: .center)
                Color.clear
                    .frame(width: 28)
            }
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { setIndex, set in
                    let workingSetNumber = entry.sets.prefix(setIndex).filter { !$0.isWarmup }.count + 1
                    SetRowView(
                        setNumber: workingSetNumber,
                        logSet: set,
                        plannedSet: viewModel.plannedSet(exerciseIndex: exerciseIndex, setIndex: setIndex),
                        isActive: viewModel.isActiveSet(exerciseIndex: exerciseIndex, setIndex: setIndex),
                        isUpdating: viewModel.updatedSetKeys.contains("\(exerciseIndex)-\(setIndex)"),
                        isAdjusting: viewModel.isAdjusting,
                        adjustmentFailed: viewModel.adjustmentFailed,
                        onLog: { weight, reps, rpe in
                            viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight, reps: reps, rpe: rpe)
                        },
                        onEdit: { weight, reps, rpe in
                            viewModel.editSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight, reps: reps, rpe: rpe)
                        }
                    )
                    if setIndex < entry.sets.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }

    // MARK: - Cancel Button

    private func cancelButton(viewModel: ActiveWorkoutViewModel) -> some View {
        Button {
            if viewModel.completedSets > 0 {
                showNativeAlert(
                    title: "Discard Workout?",
                    message: "You've logged \(viewModel.completedSets) sets. This can't be undone.",
                    confirmTitle: "Discard",
                    isDestructive: true
                ) { dismissWorkout(viewModel: viewModel) }
            } else {
                dismissWorkout(viewModel: viewModel)
            }
        } label: {
            Text("Cancel Workout")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }

    // MARK: - Actions

    private func dismissWorkout(viewModel: ActiveWorkoutViewModel) {
        showChat = false
        viewModel.stop()
        dismiss()
        logger.info("workout_session discard completedSets=\(viewModel.completedSets, privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            appState.activeViewModel = nil
        }
    }

    @MainActor
    private func finishWorkout(viewModel: ActiveWorkoutViewModel) {
        workoutFinishedCount += 1
        showChat = false
        debriefRecentLogs = recentLogs.prefix(14).map { WorkoutLogSnapshot(from: $0) }
        logger.info(
            "workout_session finish_start completedSets=\(viewModel.completedSets, privacy: .public) completedExercises=\(viewModel.completedExercises, privacy: .public)"
        )
        let log = viewModel.finish()
        log.entries = ExerciseNameResolver.canonicalize(
            entries: log.entries,
            references: exercises.map(ExerciseReference.init)
        )
        modelContext.insert(log)
        finishedLog = log
        showingDebrief = true
        logger.info(
            "workout_session finish_success entries=\(log.entries.count, privacy: .public) totalSets=\(log.totalSets, privacy: .public) durationMinutes=\(log.durationMinutes, privacy: .public)"
        )

        // Persist new exercises to library and resolve targetMuscles in the background
        Task {
            await ExerciseLibraryService.resolveAndPersistNewExercises(
                entries: log.entries,
                apiKey: apiKey,
                modelContext: modelContext
            )

            // Backfill targetMuscles on the log's entries so the muscle map works
            let resolved = ExerciseLibraryService.resolvedTargetMuscles(
                for: log.entries,
                modelContext: modelContext
            )
            var updatedEntries = log.entries
            for i in updatedEntries.indices {
                let key = ExerciseNameResolver.normalize(updatedEntries[i].exerciseName)
                if let muscles = resolved[key], !muscles.isEmpty {
                    updatedEntries[i].targetMuscles = muscles
                }
            }
            log.entries = updatedEntries
            logger.info("workout_session finish_backfill_success entries=\(updatedEntries.count, privacy: .public)")
        }
    }

    private func streamMidWorkoutChat(
        viewModel: ActiveWorkoutViewModel,
        _ message: String,
        history: [ChatMessage]
    ) async -> AsyncThrowingStream<ChatStreamEvent, Error>? {
        let currentWorkout = viewModel.currentWorkout
        let profileSnapshot = UserProfileSnapshot(from: profile)
        let version = viewModel.claimNextMutationVersion()
        logger.info(
            "mid_workout_chat start history=\(history.count, privacy: .public) version=\(version, privacy: .public) completedSets=\(viewModel.completedSets, privacy: .public)"
        )
        do {
            let stream = try await ChatAIService.stream(
                apiKey: apiKey,
                message: message,
                currentWorkout: currentWorkout,
                profile: profileSnapshot,
                exercises: exercises.map { ExerciseSnapshot(from: $0) },
                history: history,
                progress: viewModel.entries
            )

            // Wrap to intercept results and apply workout changes
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await event in stream {
                            switch event {
                            case .result(let result):
                                if let workout = result.workout {
                                    if viewModel.tryApplyModifiedWorkout(workout, expectedVersion: version) {
                                        logger.info(
                                            "mid_workout_chat apply_success version=\(version, privacy: .public) exercises=\(workout.exercises.count, privacy: .public) totalSets=\(workout.totalSets, privacy: .public)"
                                        )
                                        continuation.yield(event)
                                    } else {
                                        logger.info("mid_workout_chat discard_stale version=\(version, privacy: .public)")
                                        continuation.yield(.result(ChatResult(
                                            workout: nil,
                                            explanation: "The workout changed while I was responding, so I didn't apply these suggestions. Ask again if you still want to update the plan."
                                        )))
                                    }
                                } else {
                                    logger.info("mid_workout_chat no_workout_change version=\(version, privacy: .public)")
                                    continuation.yield(event)
                                }
                            case .usage, .text, .applying:
                                continuation.yield(event)
                            }
                        }
                        continuation.finish()
                    } catch {
                        logger.error("mid_workout_chat failure errorType=\(String(reflecting: type(of: error)), privacy: .public)")
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            logger.error("mid_workout_chat setup_failure errorType=\(String(reflecting: type(of: error)), privacy: .public)")
            return AsyncThrowingStream { continuation in
                continuation.yield(.text("Error: \(error.localizedDescription)"))
                continuation.finish()
            }
        }
    }
}

// MARK: - Native Alert Helper

private func showNativeAlert(
    title: String,
    message: String,
    confirmTitle: String,
    isDestructive: Bool,
    onConfirm: @escaping () -> Void
) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = windowScene.windows.first?.rootViewController else { return }

    var topVC = root
    while let presented = topVC.presentedViewController {
        topVC = presented
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: confirmTitle, style: isDestructive ? .destructive : .default) { _ in
        onConfirm()
    })
    topVC.present(alert, animated: true)
}
