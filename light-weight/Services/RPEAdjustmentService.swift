import Foundation
import os

private let logger = Logger(subsystem: "com.strong-ai", category: "RPEAdjustment")

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
        """

        guard let workoutJSON = try? JSONEncoder().encode(workout),
              let workoutStr = String(data: workoutJSON, encoding: .utf8) else {
            return nil
        }

        let userMessage = """
        Current workout plan:
        \(workoutStr)

        Progress:
        \(formatProgress(progress))
        """

        do {
            let (response, _) = try await api.send(systemPrompt: systemPrompt, userMessage: userMessage)
            let jsonString = JSONExtractor.extractObject(from: response)
            guard let data = jsonString.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(Workout.self, from: data)
        } catch {
            logger.error("RPE adjustment failed: \(error)")
            return nil
        }
    }

    private static func formatProgress(_ entries: [LogEntry]) -> String {
        entries.map { entry in
            let sets = entry.sets.enumerated().map { i, set in
                if set.completedAt != nil {
                    let rpeStr = " @RPE \(set.rpe)"
                    return "  Set \(i + 1): COMPLETED - \(Int(set.weight))lbs x \(set.reps)\(rpeStr)"
                } else {
                    return "  Set \(i + 1): PLANNED - \(Int(set.weight))lbs x \(set.reps)"
                }
            }.joined(separator: "\n")
            return "\(entry.exerciseName) (\(entry.muscleGroup)):\n\(sets)"
        }.joined(separator: "\n")
    }
}
