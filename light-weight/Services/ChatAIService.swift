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
    var workout: Workout?
    var explanation: String
}

struct ChatAIService {

    private static let separatorPattern = /---\s*JSON/
        .ignoresCase()
    private static let applyingTimeout: Duration = .seconds(30)

    enum StreamError: LocalizedError {
        case applyingTimedOut

        var errorDescription: String? {
            switch self {
            case .applyingTimedOut:
                "Applying changes timed out. Please try again."
            }
        }
    }

    private actor StreamCursor {
        var iterator: AsyncThrowingStream<StreamChunk, Error>.Iterator

        init(stream: AsyncThrowingStream<StreamChunk, Error>) {
            iterator = stream.makeAsyncIterator()
        }

        func next() async throws -> StreamChunk? {
            var iterator = iterator
            let chunk = try await iterator.next()
            self.iterator = iterator
            return chunk
        }
    }

    private enum NextChunkResult: Sendable {
        case chunk(StreamChunk?)
        case timedOut
    }

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
        You are an expert strength coach chatting with a user about their workout.

        If the user is just asking a question or chatting, respond conversationally. Do NOT include workout JSON.

        Only when the user asks you to \(mode) the workout, respond in this EXACT format — explanation first, then JSON after a separator:

        Write a detailed explanation of what you changed and why — mention specific exercises, sets, reps, or weight choices and the reasoning behind them (e.g. muscle balance, fatigue management, progressive overload, the user's goals or injuries). Be thorough so the user understands your coaching decisions.
        ---JSON
        {
          "name": "Workout Name",
          "insight": "One sentence explaining why this workout was programmed.",
          "exercises": [
            {
              "name": "Exercise Name",
              "muscleGroup": "Muscle Group",
              "supersetGroupId": null,
              "sets": [
                { "reps": 8, "weight": 135, "restSeconds": 90, "targetRpe": 8, "isWarmup": false }
              ]
            }
          ]
        }

        You MUST set targetRpe (1-10) for every set.
        Use "isWarmup": true for warmup sets (lighter weight, higher reps, lower RPE). Typically 1-2 warmup sets per compound exercise at 50-70% working weight.
        All weights must be in 2.5 lb increments (real plate math). No odd numbers like 186 — use 185 or 187.5.
        Never return duplicate exercise names. If an exercise matches the current workout or the library, reuse its exact name.
        For new exercises, follow the naming style of the existing library (e.g., if "Tricep Pushdown - Cable, Straight Bar" exists, a rope variation should be "Tricep Pushdown - Cable, Rope").
        Use supersetGroupId (integer) to group exercises into supersets — exercises with the same ID are performed back-to-back. Use null for standalone exercises. Superset exercises must be adjacent. Preserve existing supersetGroupId groupings unless the user asks to change them.

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

        logger.info(
            "chat_stream start mode=\(mode, privacy: .public) history=\(history.count, privacy: .public) currentWorkout=\(currentWorkout != nil, privacy: .public) activeWorkout=\(isActiveWorkout, privacy: .public)"
        )
        let tokenStream = try await api.stream(
            operation: "chat_stream",
            systemPrompt: systemPrompt,
            messages: messages
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulated = ""
                var sentExplanationUpTo = 0
                let cursor = StreamCursor(stream: tokenStream)

                do {
                    var hitSeparator = false
                    while let chunk = try await nextChunk(
                        from: cursor,
                        timeout: hitSeparator ? applyingTimeout : nil
                    ) {
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
                    if let workout = result.workout {
                        result.workout = ExerciseNameResolver.canonicalize(
                            workout: workout,
                            references: workoutReferences
                        )
                        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
                        logger.info(
                            "chat_stream success exercises=\(workout.exercises.count, privacy: .public) totalSets=\(totalSets, privacy: .public)"
                        )
                    }
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

    private static func nextChunk(
        from cursor: StreamCursor,
        timeout: Duration?
    ) async throws -> StreamChunk? {
        guard let timeout else {
            return try await cursor.next()
        }

        let result = try await withThrowingTaskGroup(of: NextChunkResult.self) { group in
            group.addTask {
                .chunk(try await cursor.next())
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return .timedOut
            }

            guard let firstResult = try await group.next() else {
                return NextChunkResult.chunk(nil)
            }

            group.cancelAll()
            return firstResult
        }

        switch result {
        case .chunk(let chunk):
            return chunk
        case .timedOut:
            throw StreamError.applyingTimedOut
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

        guard let data = jsonString.data(using: .utf8),
              let workout = try? JSONDecoder().decode(Workout.self, from: data) else {
            // No valid workout JSON found — treat as text-only
            let text = explanation.isEmpty
                ? response.trimmingCharacters(in: .whitespacesAndNewlines)
                : explanation
            return ChatResult(workout: nil, explanation: text)
        }

        return ChatResult(workout: workout, explanation: explanation)
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
