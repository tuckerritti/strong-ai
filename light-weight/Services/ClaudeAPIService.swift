import Foundation
import AnthropicSwiftSDK

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

    private var client: Anthropic { Anthropic(apiKey: apiKey) }

    func send(systemPrompt: String, userMessage: String) async throws -> (String, TokenCost) {
        try await send(systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func send(systemPrompt: String, messages: [Message]) async throws -> (String, TokenCost) {
        let response = try await client.messages.createMessage(
            messages,
            model: .custom("claude-sonnet-4-6"),
            system: [.text(systemPrompt, nil)],
            maxTokens: 2048
        )

        let cost = TokenCost(
            inputTokens: response.usage.inputTokens ?? 0,
            outputTokens: response.usage.outputTokens ?? 0
        )

        for content in response.content {
            if case .text(let text, _) = content {
                return (text, cost)
            }
        }
        throw APIError.invalidResponse
    }

    func stream(systemPrompt: String, userMessage: String) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        try await stream(systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func stream(systemPrompt: String, messages: [Message]) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let stream = try await client.messages.streamMessage(
            messages,
            model: .custom("claude-sonnet-4-6"),
            system: [.text(systemPrompt, nil)],
            maxTokens: 2048
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in stream {
                        if let delta = chunk as? StreamingContentBlockDeltaResponse,
                           delta.delta.type == .text,
                           let text = delta.delta.text {
                            continuation.yield(.text(text))
                        } else if let messageDelta = chunk as? StreamingMessageDeltaResponse {
                            let cost = TokenCost(
                                inputTokens: messageDelta.usage.inputTokens ?? 0,
                                outputTokens: messageDelta.usage.outputTokens ?? 0
                            )
                            continuation.yield(.usage(cost))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
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
