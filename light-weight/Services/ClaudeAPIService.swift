import Foundation
import AnthropicSwiftSDK
import os

private let logger = Logger(subsystem: "com.light-weight", category: "ClaudeAPI")

// MARK: - Token Cost

struct TokenCost: Sendable {
    var inputTokens: Int
    var outputTokens: Int

    var estimatedCost: Double {
        let inputCost = Double(inputTokens) * 3.0 / 1_000_000
        let outputCost = Double(outputTokens) * 15.0 / 1_000_000
        return inputCost + outputCost
    }

    static let zero = TokenCost(inputTokens: 0, outputTokens: 0)

    static func + (lhs: TokenCost, rhs: TokenCost) -> TokenCost {
        TokenCost(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens
        )
    }
}

// MARK: - Stream Chunk

enum StreamChunk: Sendable {
    case text(String)
    case usage(TokenCost)
}

// MARK: - API Service

struct ClaudeAPIService: Sendable {
    var apiKey: String
    var onCost: @Sendable (TokenCost) -> Void = { _ in }
    private static let modelName = "claude-sonnet-4-6"

    private var client: Anthropic { Anthropic(apiKey: apiKey) }

    private static func publicErrorType(_ error: Error) -> String {
        String(reflecting: type(of: error))
    }

    func send(operation: String, systemPrompt: String, userMessage: String) async throws -> String {
        try await send(operation: operation, systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func send(operation: String, systemPrompt: String, messages: [Message]) async throws -> String {
        let startedAt = Date()
        logger.info(
            "claude_request start operation=\(operation, privacy: .public) streaming=false model=\(Self.modelName, privacy: .public) messages=\(messages.count, privacy: .public)"
        )

        do {
            let response = try await client.messages.createMessage(
                messages,
                model: .custom(Self.modelName),
                system: [.text(systemPrompt, nil)],
                maxTokens: 4096
            )

            let cost = TokenCost(
                inputTokens: response.usage.inputTokens ?? 0,
                outputTokens: response.usage.outputTokens ?? 0
            )
            onCost(cost)

            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.info(
                "claude_request success operation=\(operation, privacy: .public) streaming=false durationMs=\(durationMs, privacy: .public) inputTokens=\(cost.inputTokens, privacy: .public) outputTokens=\(cost.outputTokens, privacy: .public)"
            )

            for content in response.content {
                if case .text(let text, _) = content {
                    return text
                }
            }

            logger.error("claude_request invalid_response operation=\(operation, privacy: .public) streaming=false")
            throw APIError.invalidResponse
        } catch {
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.error(
                "claude_request failure operation=\(operation, privacy: .public) streaming=false durationMs=\(durationMs, privacy: .public) errorType=\(Self.publicErrorType(error), privacy: .public) error=\(String(describing: error), privacy: .private)"
            )
            throw error
        }
    }

    func stream(operation: String, systemPrompt: String, userMessage: String) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        try await stream(operation: operation, systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func stream(operation: String, systemPrompt: String, messages: [Message]) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let startedAt = Date()
        logger.info(
            "claude_request start operation=\(operation, privacy: .public) streaming=true model=\(Self.modelName, privacy: .public) messages=\(messages.count, privacy: .public)"
        )

        do {
            let stream = try await client.messages.streamMessage(
                messages,
                model: .custom(Self.modelName),
                system: [.text(systemPrompt, nil)],
                maxTokens: 4096
            )

            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        var finalCost = TokenCost.zero
                        for try await chunk in stream {
                            if let delta = chunk as? StreamingContentBlockDeltaResponse,
                               delta.delta.type == .text,
                               let text = delta.delta.text {
                                continuation.yield(.text(text))
                            } else if let messageStart = chunk as? StreamingMessageStartResponse {
                                finalCost.inputTokens = max(finalCost.inputTokens, messageStart.message.usage.inputTokens ?? 0)
                                finalCost.outputTokens = max(finalCost.outputTokens, messageStart.message.usage.outputTokens ?? 0)
                            } else if let messageDelta = chunk as? StreamingMessageDeltaResponse {
                                finalCost.inputTokens = max(finalCost.inputTokens, messageDelta.usage.inputTokens ?? 0)
                                finalCost.outputTokens = max(finalCost.outputTokens, messageDelta.usage.outputTokens ?? 0)
                            }
                        }
                        onCost(finalCost)
                        continuation.yield(.usage(finalCost))
                        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                        logger.info(
                            "claude_request success operation=\(operation, privacy: .public) streaming=true durationMs=\(durationMs, privacy: .public) inputTokens=\(finalCost.inputTokens, privacy: .public) outputTokens=\(finalCost.outputTokens, privacy: .public)"
                        )
                        continuation.finish()
                    } catch {
                        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                        logger.error(
                            "claude_request failure operation=\(operation, privacy: .public) streaming=true durationMs=\(durationMs, privacy: .public) errorType=\(Self.publicErrorType(error), privacy: .public) error=\(String(describing: error), privacy: .private)"
                        )
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.error(
                "claude_request failure operation=\(operation, privacy: .public) streaming=true durationMs=\(durationMs, privacy: .public) errorType=\(Self.publicErrorType(error), privacy: .public) error=\(String(describing: error), privacy: .private)"
            )
            throw error
        }
    }

    enum APIError: LocalizedError {
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Invalid response from Claude API"
            }
        }
    }
}
