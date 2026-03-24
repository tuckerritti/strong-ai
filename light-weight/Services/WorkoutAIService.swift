import Foundation
import MuscleMap
import os

private let logger = Logger(subsystem: "com.light-weight", category: "WorkoutAI")

struct WorkoutAIService {

    static func generateDailyWorkout(
        apiKey: String,
        profile: UserProfileSnapshot,
        recentLogs: [WorkoutLogSnapshot],
        exercises: [ExerciseSnapshot],
        healthContext: HealthContext? = nil
    ) async throws -> (Workout, TokenCost) {
        let api = ClaudeAPIService(apiKey: apiKey)

        let systemPrompt = """
        You are an expert strength & conditioning coach. Generate a single workout as JSON.

        Respond with ONLY valid JSON matching this schema — no markdown, no explanation:
        {
          "name": "Workout Name",
          "insight": "One sentence explaining why you programmed this specific workout today.",
          "exercises": [
            {
              "name": "Exercise Name",
              "muscleGroup": "Muscle Group",
              "targetMuscles": [{"muscle": "chest", "weight": 0.6}, {"muscle": "front-deltoid", "weight": 0.2}, {"muscle": "triceps", "weight": 0.2}],
              "sets": [
                { "reps": 8, "weight": 135, "restSeconds": 90 }
              ]
            }
          ]
        }

        Guidelines:
        - Program intelligently based on the user's goals, schedule, equipment, and injuries
        - Use progressive overload: reference recent workout logs to pick appropriate weights
        - Vary muscle groups day-to-day so the user doesn't repeat the same muscles back-to-back
        - Rest seconds: 60-90 for hypertrophy, 120-180 for strength, 30-45 for accessories
        - Weight in lbs. Use 0 for bodyweight exercises.
        - When the user's exercise library contains a matching exercise, use its EXACT name. Prefer library exercises over inventing new ones unless the workout calls for something different.
        - targetMuscles: for each exercise, list muscles worked with a weight (0-1) representing that muscle's share of the work. Weights should sum to ~1.0. Valid muscle values: \(Muscle.validPromptValues)
        """

        let userMessage = buildUserContext(profile: profile, recentLogs: recentLogs, exercises: exercises, healthContext: healthContext)
        let (response, cost) = try await api.send(systemPrompt: systemPrompt, userMessage: userMessage)
        return (try parseWorkout(from: response), cost)
    }

    static func generateDebrief(
        apiKey: String,
        log: WorkoutLogSnapshot,
        recentLogs: [WorkoutLogSnapshot],
        profile: UserProfileSnapshot
    ) async throws -> (String, TokenCost) {
        let api = ClaudeAPIService(apiKey: apiKey)

        let systemPrompt = """
        You are an expert strength coach reviewing a just-completed workout. Give a brief, \
        encouraging debrief (3-5 sentences). Mention:
        - Any personal records or notable improvements vs recent sessions
        - Total volume and how it compares to recent workouts
        - Any fatigue or form concerns based on RPE values
        - One specific suggestion for next session

        Be concise and motivating. No JSON — just plain text.
        """

        let userMessage = """
        Just finished: \(log.workoutName)
        Duration: \(log.durationMinutes) min
        Exercises:
        \(log.entries.map { entry in
            "- \(entry.exerciseName): \(entry.sets.map { "\(Int($0.weight))lbs x\($0.reps)\($0.rpe.map { " @RPE\($0)" } ?? "")" }.joined(separator: ", "))"
        }.joined(separator: "\n"))

        Recent history:
        \(recentLogs.prefix(5).map { "\($0.workoutName) — \($0.durationMinutes)min, \(Int($0.totalVolume))lbs total" }.joined(separator: "\n"))

        Goals: \(profile.goals)
        """

        let (text, cost) = try await api.send(systemPrompt: systemPrompt, userMessage: userMessage)
        return (text, cost)
    }

    // MARK: - Private

    private static func buildUserContext(
        profile: UserProfileSnapshot,
        recentLogs: [WorkoutLogSnapshot],
        exercises: [ExerciseSnapshot],
        healthContext: HealthContext? = nil
    ) -> String {
        var parts: [String] = []

        parts.append("Today: \(Date.now.formatted(.dateTime.weekday(.wide).month().day()))")

        if !profile.goals.isEmpty { parts.append("Goals: \(profile.goals)") }
        if !profile.schedule.isEmpty { parts.append("Schedule: \(profile.schedule)") }
        if !profile.equipment.isEmpty { parts.append("Equipment: \(profile.equipment)") }
        if !profile.injuries.isEmpty { parts.append("Injuries/limitations: \(profile.injuries)") }

        if let health = healthContext, !health.promptFragment.isEmpty {
            parts.append(health.promptFragment)
        }

        if !exercises.isEmpty {
            let grouped = Dictionary(grouping: exercises, by: \.muscleGroup)
            let libraryStr = grouped.map { "\($0.key): \($0.value.map(\.name).joined(separator: ", "))" }.joined(separator: "\n")
            parts.append("Exercise library:\n\(libraryStr)")
        }

        if !recentLogs.isEmpty {
            let logsStr = recentLogs.prefix(5).map { log in
                let exercises = log.entries.map { "\($0.exerciseName) \($0.sets.count)x\($0.sets.first.map { "\($0.reps)@\(Int($0.weight))lbs" } ?? "")" }.joined(separator: ", ")
                return "- \(log.workoutName) (\(log.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))): \(exercises)"
            }.joined(separator: "\n")
            parts.append("Recent workouts:\n\(logsStr)")
        } else {
            parts.append("No workout history yet — this is the user's first session. Start moderate.")
        }

        return parts.joined(separator: "\n\n")
    }

    static func parseWorkout(from response: String) throws -> Workout {
        let jsonString = JSONExtractor.extractObject(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(Workout.self, from: data)
        } catch {
            logger.error("Workout decode failed: \(String(describing: error))")
            throw ParseError.decodingFailed(String(describing: error))
        }
    }

    enum ParseError: LocalizedError {
        case invalidJSON
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON: "Could not find valid JSON in AI response"
            case .decodingFailed(let msg): "Failed to parse workout: \(msg)"
            }
        }
    }
}

// MARK: - Shared JSON extraction

enum JSONExtractor {
    /// Extracts the outermost JSON object from a string by matching balanced braces.
    static func extractObject(from text: String) -> String {
        guard let openIndex = text.firstIndex(of: "{") else { return text }

        var depth = 0
        var inString = false
        var escape = false

        for i in text.indices[openIndex...] {
            let ch = text[i]

            if escape { escape = false; continue }
            if ch == "\\" && inString { escape = true; continue }
            if ch == "\"" { inString.toggle(); continue }

            guard !inString else { continue }

            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[openIndex...i])
                }
            }
        }

        // Fallback: return from first brace to end
        return String(text[openIndex...])
    }
}

// MARK: - Sendable snapshots (to cross actor boundaries from @MainActor SwiftData models)

struct UserProfileSnapshot: Sendable {
    var goals: String
    var schedule: String
    var equipment: String
    var injuries: String
}

struct WorkoutLogSnapshot: Sendable {
    var workoutName: String
    var startedAt: Date
    var durationMinutes: Int
    var totalVolume: Double
    var entries: [LogEntry]
}

struct ExerciseSnapshot: Sendable {
    var name: String
    var muscleGroup: String
    var targetMuscles: [TargetMuscle]
}

// MARK: - Valid muscle values for AI prompts

extension Muscle {
    private static let nonExerciseParts: Set<Muscle> = [.head, .hands, .feet, .knees, .ankles]

    static let validPromptValues: String = Muscle.allCases
        .filter { !nonExerciseParts.contains($0) }
        .map(\.rawValue)
        .joined(separator: ", ")
}
