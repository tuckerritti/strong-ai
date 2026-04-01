import Foundation
import AnthropicSwiftSDK
import MuscleMap
import os

private let logger = Logger(subsystem: "com.light-weight", category: "ChatAI")

enum ChatStreamEvent: Sendable {
    case text(String)
    case applying
    case result(ChatResult)
    case usage(TokenCost)
}

struct ChatResult: Sendable, Codable {
    var workout: Workout
    var explanation: String
}

struct ChatAIService {

    private static let separatorPattern = /---\s*JSON/
        .ignoresCase()

    static func stream(
        apiKey: String,
        message: String,
        currentWorkout: Workout?,
        profile: UserProfileSnapshot,
        exercises: [ExerciseSnapshot],
        history: [ChatMessage] = [],
        progress: [LogEntry]? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let api = ClaudeAPIService(apiKey: apiKey)

        let mode = currentWorkout != nil ? "modify" : "create"
        let isActiveWorkout = progress != nil
        let workoutReferences = (currentWorkout?.exercises.map(ExerciseReference.init) ?? [])
            + exercises.map(ExerciseReference.init)

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
                { "reps": 8, "weight": 135, "restSeconds": 90, "targetRpe": 8 }
              ]
            }
          ]
        }

        You MUST set targetRpe (1-10) for every set.
        Never return duplicate exercise names. If an exercise matches the current workout or the library, reuse its exact name.
        For new exercises, follow the naming style of the existing library (e.g., if "Tricep Pushdown - Cable, Straight Bar" exists, a rope variation should be "Tricep Pushdown - Cable, Rope").

        \(currentWorkout != nil ? "The user has an existing workout. Modify it based on their request — keep exercises they didn't mention, adjust what they asked about." : "Create a new workout from scratch based on the user's request.")
        \(isActiveWorkout ? "\nIMPORTANT: This workout is in progress. Sets marked COMPLETED in the progress below cannot be changed. You MUST include them exactly as-is in your response. Only modify PLANNED sets and exercises." : "")

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

        if let progress {
            userMessage += "\n\nWorkout progress:\n" + progress.formattedProgress()
        }

        // Build multi-turn message array from history
        var messages: [Message] = history.map { chatMsg in
            Message(role: chatMsg.role == .user ? .user : .assistant, content: [.text(chatMsg.text)])
        }
        messages.append(Message(role: .user, content: [.text(userMessage)]))

        let tokenStream = try await api.stream(systemPrompt: systemPrompt, messages: messages)

        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulated = ""
                var sentExplanationUpTo = 0

                do {
                    var hitSeparator = false
                    for try await chunk in tokenStream {
                        switch chunk {
                        case .text(let token):
                            accumulated += token

                            // Stream explanation text (everything before separator)
                            if let match = accumulated.firstMatch(of: separatorPattern) {
                                let explanation = String(accumulated[accumulated.startIndex..<match.range.lowerBound])
                                if explanation.count > sentExplanationUpTo {
                                    let new = String(explanation.dropFirst(sentExplanationUpTo))
                                    continuation.yield(.text(new))
                                    sentExplanationUpTo = explanation.count
                                }
                                if !hitSeparator {
                                    hitSeparator = true
                                    continuation.yield(.applying)
                                }
                            } else {
                                // Haven't hit separator yet — stream with holdback buffer
                                // to avoid leaking partial separator text (e.g. "---")
                                let safeEnd = max(sentExplanationUpTo, accumulated.count - 10)
                                if safeEnd > sentExplanationUpTo {
                                    let new = String(accumulated.dropFirst(sentExplanationUpTo).prefix(safeEnd - sentExplanationUpTo))
                                    continuation.yield(.text(new))
                                    sentExplanationUpTo = safeEnd
                                }
                            }
                        case .usage(let cost):
                            continuation.yield(.usage(cost))
                        }
                    }

                    // Parse the final result
                    var result = try parseResult(from: accumulated)
                    result.workout = ExerciseNameResolver.canonicalize(
                        workout: result.workout,
                        references: workoutReferences
                    )
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

        if let match = response.firstMatch(of: separatorPattern) {
            explanation = response[response.startIndex..<match.range.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let afterSeparator = String(response[match.range.upperBound...])
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
