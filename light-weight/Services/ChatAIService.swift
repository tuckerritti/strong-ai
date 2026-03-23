import Foundation
import os

private let logger = Logger(subsystem: "com.light-weight", category: "ChatAI")

enum ChatStreamEvent: Sendable {
    case text(String)
    case result(ChatResult)
}

struct ChatResult: Sendable, Codable {
    var workout: Workout
    var explanation: String
}

struct ChatAIService {

    static func stream(
        apiKey: String,
        message: String,
        currentWorkout: Workout?,
        profile: UserProfileSnapshot,
        exercises: [ExerciseSnapshot]
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let api = ClaudeAPIService(apiKey: apiKey)

        let mode = currentWorkout != nil ? "modify" : "create"

        let systemPrompt = """
        You are an expert strength coach. The user is asking you to \(mode) a workout via natural language.

        Respond in this EXACT format — explanation first, then JSON after a separator:

        Write 1-2 sentences explaining what you did and why.
        ---JSON
        {
          "name": "Workout Name",
          "insight": "One sentence explaining why this workout was programmed.",
          "exercises": [
            {
              "name": "Exercise Name",
              "muscleGroup": "Muscle Group",
              "sets": [
                { "reps": 8, "weight": 135, "restSeconds": 90 }
              ]
            }
          ]
        }

        \(currentWorkout != nil ? "The user has an existing workout. Modify it based on their request — keep exercises they didn't mention, adjust what they asked about." : "Create a new workout from scratch based on the user's request.")

        User context:
        Goals: \(profile.goals.isEmpty ? "Not specified" : profile.goals)
        Equipment: \(profile.equipment.isEmpty ? "Not specified" : profile.equipment)
        Injuries: \(profile.injuries.isEmpty ? "None" : profile.injuries)
        \(exercises.isEmpty ? "" : "\nExercise library (use exact names when referencing these):\n\(Dictionary(grouping: exercises, by: \.muscleGroup).map { "\($0.key): \($0.value.map(\.name).joined(separator: ", "))" }.joined(separator: "\n"))")
        """

        var userMessage = message
        if let workout = currentWorkout,
           let json = try? JSONEncoder().encode(workout),
           let str = String(data: json, encoding: .utf8) {
            userMessage += "\n\nCurrent workout:\n\(str)"
        }

        let tokenStream = try await api.stream(systemPrompt: systemPrompt, userMessage: userMessage)

        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulated = ""
                var sentExplanationUpTo = 0

                do {
                    for try await token in tokenStream {
                        accumulated += token

                        // Stream explanation text (everything before ---JSON)
                        if let separatorRange = accumulated.range(of: "---JSON") {
                            let explanation = String(accumulated[accumulated.startIndex..<separatorRange.lowerBound])
                            if explanation.count > sentExplanationUpTo {
                                let new = String(explanation.dropFirst(sentExplanationUpTo))
                                continuation.yield(.text(new))
                                sentExplanationUpTo = explanation.count
                            }
                        } else {
                            // Haven't hit separator yet — stream everything so far
                            if accumulated.count > sentExplanationUpTo {
                                let new = String(accumulated.dropFirst(sentExplanationUpTo))
                                continuation.yield(.text(new))
                                sentExplanationUpTo = accumulated.count
                            }
                        }
                    }

                    // Parse the final result
                    let result = try parseResult(from: accumulated)
                    continuation.yield(.result(result))
                    continuation.finish()
                } catch {
                    logger.error("Chat stream failed: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseResult(from response: String) throws -> ChatResult {
        let explanation: String
        let jsonString: String

        if let separatorRange = response.range(of: "---JSON") {
            explanation = response[response.startIndex..<separatorRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let afterSeparator = String(response[separatorRange.upperBound...])
            jsonString = JSONExtractor.extractObject(from: afterSeparator)
        } else {
            // Fallback: try to find JSON in the whole response
            explanation = ""
            jsonString = JSONExtractor.extractObject(from: response)
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw ChatParseError.invalidJSON
        }

        do {
            let workout = try JSONDecoder().decode(Workout.self, from: data)
            return ChatResult(workout: workout, explanation: explanation)
        } catch {
            logger.error("Chat workout decode failed: \(String(describing: error))")
            throw ChatParseError.decodingFailed(String(describing: error))
        }
    }

    enum ChatParseError: LocalizedError {
        case invalidJSON
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON: "Could not find valid JSON in chat response"
            case .decodingFailed(let msg): "Failed to parse chat workout: \(msg)"
            }
        }
    }
}
