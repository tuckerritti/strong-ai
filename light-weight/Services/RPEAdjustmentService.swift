import Foundation
import os

private let logger = Logger(subsystem: "com.light-weight", category: "RPEAdjustment")

struct RPEAdjustmentService {

    /// Sends the full workout state to Claude to get holistic adjustments
    /// based on RPE data across all exercises (fatigue transfer, etc.).
    /// Returns an adjusted workout, or nil if the call fails.
    static func adjustWorkout(
        apiKey: String,
        workout: Workout,
        progress: [LogEntry]
    ) async -> Workout? {
        let api = ClaudeAPIService(apiKey: apiKey)
        let completedSetCount = progress.flatMap(\.sets).filter { $0.completedAt != nil }.count
        logger.info(
            "rpe_adjustment start exercises=\(workout.exercises.count, privacy: .public) completedSets=\(completedSetCount, privacy: .public)"
        )

        let systemPrompt = """
        You are an expert strength coach making real-time adjustments to a workout in progress.

        The user just logged a set with their RPE (rate of perceived exertion, 1-10 scale). \
        Analyze the RPE data across ALL completed sets and adjust the REMAINING planned sets.

        Consider:
        - If actual RPE is higher than target, the weight is too heavy, reps are too high, or rest is too short
        - If actual RPE is lower than target, the weight is too light, reps are too low, or rest is too long
        - Fatigue transfer between exercises — e.g. heavy bench press fatigues triceps for later pushdowns
        - Cumulative fatigue — RPE naturally climbs across sets, but a big jump signals a problem
        - Adjust weight, reps, rest, and targetRpe for remaining planned sets as needed
        - Keep completed sets EXACTLY as they appear — do not modify them

        Respond with ONLY the adjusted workout JSON, no explanation. Use this exact schema:
        {
          "name": "Workout Name",
          "exercises": [
            {
              "name": "Exercise Name",
              "muscleGroup": "Muscle Group",
              "sets": [
                { "reps": 8, "weight": 135, "restSeconds": 90, "targetRpe": 8 }
              ]
            }
          ]
        }

        Rules for adjustments:
        - Weight changes should use real plate increments (2.5 lb minimum)
        - Rest range: 30-300 seconds
        - Reps minimum: 1
        - If all RPEs are on target, return the workout unchanged
        - Be conservative — small adjustments are better than dramatic ones
        - Never return duplicate exercise names. If an exercise matches the current workout, reuse its exact name.
        """

        guard let workoutJSON = try? JSONEncoder().encode(workout),
              let workoutStr = String(data: workoutJSON, encoding: .utf8) else {
            return nil
        }

        let userMessage = """
        Current workout plan:
        \(workoutStr)

        Progress:
        \(progress.formattedProgress())
        """

        do {
            let response = try await api.send(
                operation: "adjust_rpe_workout",
                systemPrompt: systemPrompt,
                userMessage: userMessage
            )
            let jsonString = JSONExtractor.extractObject(from: response)
            guard let data = jsonString.data(using: .utf8) else { return nil }
            let adjustedWorkout = try JSONDecoder().decode(Workout.self, from: data)
            let totalSets = adjustedWorkout.exercises.reduce(0) { $0 + $1.sets.count }
            logger.info(
                "rpe_adjustment success exercises=\(adjustedWorkout.exercises.count, privacy: .public) totalSets=\(totalSets, privacy: .public)"
            )
            return ExerciseNameResolver.canonicalize(
                workout: adjustedWorkout,
                references: workout.exercises.map(ExerciseReference.init)
            )
        } catch {
            logger.error("RPE adjustment failed: \(error)")
            return nil
        }
    }

}
