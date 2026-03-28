import Foundation
import AnthropicSwiftSDK

struct ClaudeAPIService: Sendable {
    var apiKey: String

    private var client: Anthropic { Anthropic(apiKey: apiKey) }

    func send(systemPrompt: String, userMessage: String) async throws -> String {
        try await send(systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func send(systemPrompt: String, messages: [Message]) async throws -> String {
        let response = try await client.messages.createMessage(
            messages,
            model: .custom("claude-sonnet-4-6"),
            system: [.text(systemPrompt, nil)],
            maxTokens: 4096
        )

        for content in response.content {
            if case .text(let text, _) = content {
                return text
            }
        }
        throw APIError.invalidResponse
    }

    func stream(systemPrompt: String, userMessage: String) async throws -> AsyncThrowingStream<String, Error> {
        try await stream(systemPrompt: systemPrompt, messages: [Message(role: .user, content: [.text(userMessage)])])
    }

    func stream(systemPrompt: String, messages: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        let stream = try await client.messages.streamMessage(
            messages,
            model: .custom("claude-sonnet-4-6"),
            system: [.text(systemPrompt, nil)],
            maxTokens: 4096
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in stream {
                        if let delta = chunk as? StreamingContentBlockDeltaResponse,
                           delta.delta.type == .text,
                           let text = delta.delta.text {
                            continuation.yield(text)
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
