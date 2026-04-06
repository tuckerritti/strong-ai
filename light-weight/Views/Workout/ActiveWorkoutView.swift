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

// MARK: - View Model

@Observable
final class ActiveWorkoutViewModel {
    var entries: [LogEntry]
    var startedAt: Date
    var workoutName: String
    let timerService = TimerService()
    var apiKey: String = ""
    var updatedSetKeys: Set<String> = []
    private var latestClaimedVersion = 0

    private var workoutExercises: [WorkoutExercise]
    private var elapsedTimer: Timer?
    private var hasStarted = false

    var elapsedSeconds: Int = 0

    var totalSets: Int { entries.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count } }
    var completedSets: Int { entries.flatMap(\.sets).filter { $0.completedAt != nil && !$0.isWarmup }.count }
    var totalExercises: Int { entries.count }
    var completedExercises: Int {
        entries.reduce(0) { count, entry in
            let workingSets = entry.sets.filter { !$0.isWarmup }
            return workingSets.allSatisfy({ $0.completedAt != nil }) ? count + 1 : count
        }
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var currentWorkout: Workout {
        Workout(
            name: workoutName,
            exercises: workoutExercises
        )
    }

    init(workout: Workout) {
        self.workoutName = workout.name
        self.workoutExercises = workout.exercises
        self.startedAt = .now

        self.entries = workout.exercises.map { exercise in
            LogEntry(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup,
                targetMuscles: exercise.targetMuscles,
                sets: exercise.sets.map { plannedSet in
                    LogSet(reps: plannedSet.reps, weight: plannedSet.weight, rpe: plannedSet.targetRpe ?? 0, isWarmup: plannedSet.isWarmup)
                }
            )
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startedAt = .now
        elapsedSeconds = 0
        resumeTimer()
        logger.info("workout_session_clock start exercises=\(self.entries.count, privacy: .public) totalSets=\(self.totalSets, privacy: .public)")
    }

    func resumeTimer() {
        guard elapsedTimer == nil else { return }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startedAt))
            }
        }
    }

    func pauseTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func stop() {
        pauseTimer()
        timerService.stop()
        logger.info("workout_session_clock stop elapsedSeconds=\(self.elapsedSeconds, privacy: .public)")
    }

    deinit {
        elapsedTimer?.invalidate()
    }

    func plannedSet(exerciseIndex: Int, setIndex: Int) -> WorkoutSet? {
        guard exerciseIndex < workoutExercises.count,
              setIndex < workoutExercises[exerciseIndex].sets.count else { return nil }
        return workoutExercises[exerciseIndex].sets[setIndex]
    }

    func isActiveSet(exerciseIndex: Int, setIndex: Int) -> Bool {
        if timerService.isRunning { return false }
        for (ei, entry) in entries.enumerated() {
            for (si, set) in entry.sets.enumerated() {
                if set.completedAt == nil {
                    return ei == exerciseIndex && si == setIndex
                }
            }
        }
        return false
    }

    func logSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, rpe: Int) {
        let planned = plannedSet(exerciseIndex: exerciseIndex, setIndex: setIndex)

        entries[exerciseIndex].sets[setIndex].weight = weight
        entries[exerciseIndex].sets[setIndex].reps = reps
        entries[exerciseIndex].sets[setIndex].rpe = rpe
        entries[exerciseIndex].sets[setIndex].completedAt = .now

        if exerciseIndex < workoutExercises.count,
           setIndex < workoutExercises[exerciseIndex].sets.count {
            workoutExercises[exerciseIndex].sets[setIndex].weight = weight
            workoutExercises[exerciseIndex].sets[setIndex].reps = reps
        }

        if let planned, AppState.shared?.showRestTimer == true {
            timerService.start(seconds: planned.restSeconds)
        }

        let missedTarget = planned.map { p in
            weight != p.weight || reps != p.reps || (p.targetRpe != nil && rpe != p.targetRpe)
        } ?? false
        logger.info(
            "workout_set complete exerciseIndex=\(exerciseIndex + 1, privacy: .public) setIndex=\(setIndex + 1, privacy: .public) missedTarget=\(missedTarget, privacy: .public) timerStarted=\(planned != nil && AppState.shared?.showRestTimer == true, privacy: .public)"
        )

        if !apiKey.isEmpty && missedTarget {
            requestRPEAdjustment()
        }
    }

    func editSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, rpe: Int) {
        entries[exerciseIndex].sets[setIndex].weight = weight
        entries[exerciseIndex].sets[setIndex].reps = reps
        entries[exerciseIndex].sets[setIndex].rpe = rpe

        if exerciseIndex < workoutExercises.count,
           setIndex < workoutExercises[exerciseIndex].sets.count {
            workoutExercises[exerciseIndex].sets[setIndex].weight = weight
            workoutExercises[exerciseIndex].sets[setIndex].reps = reps
        }
    }

    func claimNextMutationVersion() -> Int {
        latestClaimedVersion += 1
        return latestClaimedVersion
    }

    func tryApplyModifiedWorkout(_ newWorkout: Workout, expectedVersion: Int) -> Bool {
        guard expectedVersion == latestClaimedVersion else { return false }
        applyModifiedWorkout(newWorkout)
        return true
    }

    private func requestRPEAdjustment() {
        let key = apiKey
        let workout = currentWorkout
        let progress = entries
        let version = claimNextMutationVersion()
        logger.info(
            "rpe_adjustment request version=\(version, privacy: .public) completedSets=\(self.completedSets, privacy: .public)"
        )

        Task {
            if let adjusted = await RPEAdjustmentService.adjustWorkout(
                apiKey: key,
                workout: workout,
                progress: progress
            ) {
                if tryApplyModifiedWorkout(adjusted, expectedVersion: version) {
                    logger.info(
                        "rpe_adjustment apply_success version=\(version, privacy: .public) exercises=\(adjusted.exercises.count, privacy: .public) totalSets=\(adjusted.totalSets, privacy: .public)"
                    )
                } else {
                    logger.info("rpe_adjustment discard_stale version=\(version, privacy: .public)")
                }
            } else {
                logger.warning("rpe_adjustment no_change version=\(version, privacy: .public)")
            }
        }
    }

    private func applyModifiedWorkout(_ newWorkout: Workout) {
        let previousExerciseCount = entries.count
        workoutName = newWorkout.name

        var updatedEntries: [LogEntry] = []
        var updatedExercises: [WorkoutExercise] = []
        var matchedExistingIndices = Set<Int>()

        for newExercise in newWorkout.exercises {
            let normalizedNewName = ExerciseNameResolver.normalize(newExercise.name)
            if let existingIndex = entries.firstIndex(where: {
                ExerciseNameResolver.normalize($0.exerciseName) == normalizedNewName
            }) {
                matchedExistingIndices.insert(existingIndex)
                let existing = entries[existingIndex]
                let completedSets = completedPrefix(from: existing.sets)

                if !completedSets.isEmpty {
                    var sets = completedSets
                    let remainingCount = max(0, newExercise.sets.count - completedSets.count)
                    for i in 0..<remainingCount {
                        let setIndex = completedSets.count + i
                        if setIndex < newExercise.sets.count {
                            let planned = newExercise.sets[setIndex]
                            sets.append(LogSet(reps: planned.reps, weight: planned.weight, rpe: planned.targetRpe ?? 0, isWarmup: planned.isWarmup))
                        }
                    }
                    updatedEntries.append(LogEntry(
                        exerciseName: existing.exerciseName,
                        muscleGroup: existing.muscleGroup,
                        targetMuscles: existing.targetMuscles,
                        sets: sets
                    ))
                    updatedExercises.append(mergedExercise(newExercise, existingIndex: existingIndex, completedSets: completedSets))
                } else {
                    updatedEntries.append(LogEntry(
                        exerciseName: newExercise.name,
                        muscleGroup: newExercise.muscleGroup,
                        targetMuscles: existing.targetMuscles,
                        sets: newExercise.sets.map { LogSet(reps: $0.reps, weight: $0.weight, rpe: $0.targetRpe ?? 0, isWarmup: $0.isWarmup) }
                    ))
                    updatedExercises.append(newExercise)
                }
            } else {
                updatedEntries.append(LogEntry(
                    exerciseName: newExercise.name,
                    muscleGroup: newExercise.muscleGroup,
                    targetMuscles: newExercise.targetMuscles,
                    sets: newExercise.sets.map { LogSet(reps: $0.reps, weight: $0.weight, rpe: $0.targetRpe ?? 0, isWarmup: $0.isWarmup) }
                ))
                updatedExercises.append(newExercise)
            }
        }

        var preservedCompletedEntries: [(Int, LogEntry, WorkoutExercise)] = []
        for (index, entry) in entries.enumerated() {
            guard !matchedExistingIndices.contains(index) else { continue }

            let completedSets = completedPrefix(from: entry.sets)
            guard !completedSets.isEmpty else { continue }

            let preservedEntry = LogEntry(
                exerciseName: entry.exerciseName,
                muscleGroup: entry.muscleGroup,
                targetMuscles: entry.targetMuscles,
                sets: completedSets
            )

            let preservedExercise = completedExercise(
                exerciseName: entry.exerciseName,
                muscleGroup: entry.muscleGroup,
                existingIndex: index,
                completedSets: completedSets
            )

            preservedCompletedEntries.append((index, preservedEntry, preservedExercise))
        }

        for (index, preservedEntry, preservedExercise) in preservedCompletedEntries {
            let entryInsertIndex = min(index, updatedEntries.count)
            updatedEntries.insert(preservedEntry, at: entryInsertIndex)

            let exerciseInsertIndex = min(index, updatedExercises.count)
            updatedExercises.insert(preservedExercise, at: exerciseInsertIndex)
        }

        workoutExercises = updatedExercises
        entries = updatedEntries

        // Flag non-completed sets for shadow sweep animation
        var keys: Set<String> = []
        for (ei, entry) in entries.enumerated() {
            for (si, set) in entry.sets.enumerated() where set.completedAt == nil {
                keys.insert("\(ei)-\(si)")
            }
        }
        updatedSetKeys = keys
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            updatedSetKeys = []
        }

        resyncTimerIfNeeded()
        logger.info(
            "workout_apply success previousExercises=\(previousExerciseCount, privacy: .public) exercises=\(self.entries.count, privacy: .public) totalSets=\(self.totalSets, privacy: .public)"
        )
    }

    private func resyncTimerIfNeeded() {
        guard timerService.isRunning, AppState.shared?.showRestTimer == true else { return }

        // Find the last completed set and its new planned rest
        for (ei, entry) in entries.enumerated().reversed() {
            for (si, set) in entry.sets.enumerated().reversed() {
                if set.completedAt != nil {
                    if let planned = plannedSet(exerciseIndex: ei, setIndex: si),
                       planned.restSeconds != timerService.totalSeconds {
                        timerService.resync(newTotalSeconds: planned.restSeconds)
                        logger.info("workout_timer resync seconds=\(planned.restSeconds, privacy: .public)")
                    }
                    return
                }
            }
        }
    }

    private func completedPrefix(from sets: [LogSet]) -> [LogSet] {
        Array(sets.prefix { $0.completedAt != nil })
    }

    private func mergedExercise(
        _ newExercise: WorkoutExercise,
        existingIndex: Int,
        completedSets: [LogSet]
    ) -> WorkoutExercise {
        let actualCompletedSets = completedSets.enumerated().map { setIndex, completedSet in
            workoutSet(
                from: completedSet,
                fallback: setIndex < newExercise.sets.count
                    ? newExercise.sets[setIndex]
                    : plannedExercise(at: existingIndex)?.sets[safe: setIndex]
            )
        }

        let remainingSets = Array(newExercise.sets.dropFirst(completedSets.count))

        return WorkoutExercise(
            name: newExercise.name,
            muscleGroup: newExercise.muscleGroup,
            targetMuscles: newExercise.targetMuscles,
            sets: actualCompletedSets + remainingSets
        )
    }

    private func completedExercise(
        exerciseName: String,
        muscleGroup: String,
        existingIndex: Int,
        completedSets: [LogSet]
    ) -> WorkoutExercise {
        let plannedExercise = plannedExercise(at: existingIndex)
        let actualCompletedSets = completedSets.enumerated().map { setIndex, completedSet in
            workoutSet(from: completedSet, fallback: plannedExercise?.sets[safe: setIndex])
        }

        return WorkoutExercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            targetMuscles: plannedExercise?.targetMuscles ?? [],
            sets: actualCompletedSets
        )
    }

    private func plannedExercise(at index: Int) -> WorkoutExercise? {
        guard index < workoutExercises.count else { return nil }
        return workoutExercises[index]
    }

    private func workoutSet(from completedSet: LogSet, fallback plannedSet: WorkoutSet?) -> WorkoutSet {
        WorkoutSet(
            reps: completedSet.reps,
            weight: completedSet.weight,
            restSeconds: plannedSet?.restSeconds ?? 90,
            targetRpe: plannedSet?.targetRpe,
            isWarmup: completedSet.isWarmup
        )
    }

    func finish() -> WorkoutLog {
        stop()

        let completedEntries = entries.compactMap { entry -> LogEntry? in
            let completedSets = entry.sets.filter { $0.completedAt != nil }
            guard !completedSets.isEmpty else { return nil }
            return LogEntry(exerciseName: entry.exerciseName, muscleGroup: entry.muscleGroup, targetMuscles: entry.targetMuscles, sets: completedSets)
        }
        let log = WorkoutLog(
            workoutName: workoutName,
            entries: completedEntries,
            startedAt: startedAt
        )
        log.finishedAt = .now
        logger.info(
            "workout_session_log build_success entries=\(completedEntries.count, privacy: .public) totalSets=\(completedEntries.reduce(0) { $0 + $1.sets.count }, privacy: .public)"
        )
        return log
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
