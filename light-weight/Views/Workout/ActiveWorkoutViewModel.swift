import os
import SwiftUI

private let logger = Logger(subsystem: "com.light-weight", category: "ActiveWorkout")

private func debugActiveWorkoutLog(_ message: String) {
    DebugLogStore.record(message, category: "ActiveWorkout")
}

// MARK: - View Model

@Observable
final class ActiveWorkoutViewModel {
    var entries: [LogEntry]
    var startedAt: Date
    var workoutName: String
    let timerService = TimerService()
    var apiKey: String = ""
    weak var appState: AppState?
    @ObservationIgnored var onCost: @Sendable (TokenCost) -> Void
    private var adjustingCount = 0
    var isAdjusting: Bool { adjustingCount > 0 }
    var adjustmentFailed = false
    var updatedSetKeys: Set<String> = []
    private var latestClaimedVersion = 0

    private var workoutExercises: [WorkoutExercise]
    private var elapsedTimer: Timer?
    private var hasStarted = false

    var elapsedSeconds: Int = 0

    var entryGroups: [[(flatIndex: Int, entry: LogEntry)]] { entries.entryGroups }

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

    init(workout: Workout, appState: AppState? = nil, onCost: @Sendable @escaping (TokenCost) -> Void = { _ in }) {
        self.workoutName = workout.name
        self.workoutExercises = workout.exercises
        self.startedAt = .now
        self.appState = appState
        self.onCost = onCost

        self.entries = workout.exercises.map { exercise in
            LogEntry(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup,
                targetMuscles: exercise.targetMuscles,
                sets: exercise.sets.map { plannedSet in
                    LogSet(reps: plannedSet.reps, weight: plannedSet.weight, rpe: plannedSet.targetRpe ?? 0, isWarmup: plannedSet.isWarmup)
                },
                supersetGroupId: exercise.supersetGroupId
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
        let next = nextUncompletedSet()
        return next?.exerciseIndex == exerciseIndex && next?.setIndex == setIndex
    }

    private func nextUncompletedSet() -> (exerciseIndex: Int, setIndex: Int)? {
        for group in entryGroups {
            if group.count > 1 {
                // Superset: round-robin through exercises per set round
                let maxSets = group.map(\.entry.sets.count).max() ?? 0
                for round in 0..<maxSets {
                    for (flatIndex, entry) in group {
                        guard round < entry.sets.count else { continue }
                        if entry.sets[round].completedAt == nil {
                            return (flatIndex, round)
                        }
                    }
                }
            } else if let (flatIndex, entry) = group.first {
                // Standalone exercise: sequential
                for (si, set) in entry.sets.enumerated() {
                    if set.completedAt == nil {
                        return (flatIndex, si)
                    }
                }
            }
        }
        return nil
    }

    func logSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, rpe: Int) {
        let planned = plannedSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
        let isWarmup = entries[exerciseIndex].sets[setIndex].isWarmup
        let fractionalWeight = weight.rounded() != weight

        entries[exerciseIndex].sets[setIndex].weight = weight
        entries[exerciseIndex].sets[setIndex].reps = reps
        entries[exerciseIndex].sets[setIndex].rpe = rpe
        entries[exerciseIndex].sets[setIndex].completedAt = .now

        if exerciseIndex < workoutExercises.count,
           setIndex < workoutExercises[exerciseIndex].sets.count {
            workoutExercises[exerciseIndex].sets[setIndex].weight = weight
            workoutExercises[exerciseIndex].sets[setIndex].reps = reps
        }

        if let planned, appState?.showRestTimer ?? false {
            let skipRest = shouldSkipRestForSuperset(exerciseIndex: exerciseIndex)
            if !skipRest {
                timerService.start(seconds: planned.restSeconds)
            }
        }

        let missedTarget = planned.map { p in
            weight != p.weight || reps != p.reps || (p.targetRpe != nil && rpe != p.targetRpe)
        } ?? false
        logger.info(
            "workout_set complete exerciseIndex=\(exerciseIndex + 1, privacy: .public) setIndex=\(setIndex + 1, privacy: .public) missedTarget=\(missedTarget, privacy: .public) timerStarted=\(planned != nil && (self.appState?.showRestTimer ?? false), privacy: .public) isWarmup=\(isWarmup, privacy: .public) fractionalWeight=\(fractionalWeight, privacy: .public)"
        )

        debugActiveWorkoutLog(
            "Logged set exercise=\(exerciseIndex) set=\(setIndex) " +
            "weight=\(weight) reps=\(reps) rpe=\(rpe) " +
            "missedTarget=\(missedTarget) hasAPIKey=\(!self.apiKey.isEmpty)"
        )

        if !apiKey.isEmpty && missedTarget {
            requestRPEAdjustment()
        }
    }

    private func shouldSkipRestForSuperset(exerciseIndex: Int) -> Bool {
        guard let groupId = entries[exerciseIndex].supersetGroupId else { return false }
        // Find the next exercise with an uncompleted set
        for ei in (exerciseIndex + 1)..<entries.count {
            guard entries[ei].supersetGroupId == groupId else { break }
            if entries[ei].sets.contains(where: { $0.completedAt == nil }) {
                return true
            }
        }
        return false
    }

    func editSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, rpe: Int) {
        let isWarmup = entries[exerciseIndex].sets[setIndex].isWarmup
        let fractionalWeight = weight.rounded() != weight
        entries[exerciseIndex].sets[setIndex].weight = weight
        entries[exerciseIndex].sets[setIndex].reps = reps
        entries[exerciseIndex].sets[setIndex].rpe = rpe

        if exerciseIndex < workoutExercises.count,
           setIndex < workoutExercises[exerciseIndex].sets.count {
            workoutExercises[exerciseIndex].sets[setIndex].weight = weight
            workoutExercises[exerciseIndex].sets[setIndex].reps = reps
        }

        logger.info(
            "workout_set edit exerciseIndex=\(exerciseIndex + 1, privacy: .public) setIndex=\(setIndex + 1, privacy: .public) isWarmup=\(isWarmup, privacy: .public) fractionalWeight=\(fractionalWeight, privacy: .public)"
        )
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
        adjustmentFailed = false
        adjustingCount += 1

        debugActiveWorkoutLog("Starting auto-RPE adjustment version=\(version) completedSets=\(self.completedSets)")
        logger.info(
            "rpe_adjustment request version=\(version, privacy: .public) completedSets=\(self.completedSets, privacy: .public)"
        )

        Task {
            defer {
                adjustingCount = max(0, adjustingCount - 1)
                debugActiveWorkoutLog("Ending auto-RPE adjustment version=\(version)")
            }

            if let adjusted = await RPEAdjustmentService.adjustWorkout(
                apiKey: key,
                workout: workout,
                progress: progress,
                onCost: onCost
            ) {
                if tryApplyModifiedWorkout(adjusted, expectedVersion: version) {
                    debugActiveWorkoutLog("Applying auto-RPE adjustment version=\(version)")
                    logger.info(
                        "rpe_adjustment apply_success version=\(version, privacy: .public) exercises=\(adjusted.exercises.count, privacy: .public) totalSets=\(adjusted.totalSets, privacy: .public)"
                    )
                } else {
                    logger.info("rpe_adjustment discard_stale version=\(version, privacy: .public)")
                }
            } else {
                triggerAdjustmentFailure(expectedVersion: version)
            }
        }
    }

    private func triggerAdjustmentFailure(expectedVersion version: Int) {
        guard version == latestClaimedVersion else {
            logger.info("rpe_adjustment discard_stale_failure version=\(version, privacy: .public)")
            return
        }

        debugActiveWorkoutLog("Auto-RPE adjustment failed version=\(version)")
        logger.warning("rpe_adjustment failure version=\(version, privacy: .public)")
        adjustmentFailed = true
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard version == latestClaimedVersion else { return }
            adjustmentFailed = false
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
                        sets: sets,
                        supersetGroupId: newExercise.supersetGroupId
                    ))
                    updatedExercises.append(mergedExercise(newExercise, existingIndex: existingIndex, completedSets: completedSets))
                } else {
                    updatedEntries.append(LogEntry(
                        exerciseName: newExercise.name,
                        muscleGroup: newExercise.muscleGroup,
                        targetMuscles: existing.targetMuscles,
                        sets: newExercise.sets.map { LogSet(reps: $0.reps, weight: $0.weight, rpe: $0.targetRpe ?? 0, isWarmup: $0.isWarmup) },
                        supersetGroupId: newExercise.supersetGroupId
                    ))
                    updatedExercises.append(newExercise)
                }
            } else {
                updatedEntries.append(LogEntry(
                    exerciseName: newExercise.name,
                    muscleGroup: newExercise.muscleGroup,
                    targetMuscles: newExercise.targetMuscles,
                    sets: newExercise.sets.map { LogSet(reps: $0.reps, weight: $0.weight, rpe: $0.targetRpe ?? 0, isWarmup: $0.isWarmup) },
                    supersetGroupId: newExercise.supersetGroupId
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

        // Flag non-completed sets for shadow sweep animation.
        var keys: Set<String> = []
        for (exerciseIndex, entry) in entries.enumerated() {
            for (setIndex, set) in entry.sets.enumerated() where set.completedAt == nil {
                keys.insert("\(exerciseIndex)-\(setIndex)")
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
        guard timerService.isRunning, appState?.showRestTimer ?? false else { return }

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
