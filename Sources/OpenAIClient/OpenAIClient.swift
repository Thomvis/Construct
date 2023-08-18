//
//  OpenAIClient.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation
import Helpers
import LDSwiftEventSource

/// Errors thrown by public functions are always of type `OpenAIError`
public struct OpenAIClient {
    private let performCompletionRequest: (CompletionRequest) async throws -> CompletionResponse
    private let streamCompletionRequest: (CompletionRequest) throws -> AsyncThrowingStream<String, Error>
    private let streamChatRequest: (ChatCompletionRequest) throws -> AsyncThrowingStream<String, Error>
    public let performModelsRequest: () async throws -> ModelsResponse

    public init(
        performCompletionRequest: @escaping (CompletionRequest) async throws -> CompletionResponse,
        streamCompletionRequest: @escaping (CompletionRequest) throws -> AsyncThrowingStream<String, Error>,
        streamChatRequest: @escaping (ChatCompletionRequest) throws -> AsyncThrowingStream<String, Error>,
        performModelsRequest: @escaping () async throws -> ModelsResponse
    ) {
        self.performCompletionRequest = performCompletionRequest
        self.streamCompletionRequest = streamCompletionRequest
        self.streamChatRequest = streamChatRequest
        self.performModelsRequest = performModelsRequest
    }
}

public extension OpenAIClient {
    func perform(request payload: CompletionRequest) async throws -> CompletionResponse {
        try await performCompletionRequest(payload)
    }

    func stream(request payload: CompletionRequest) throws -> AsyncThrowingStream<String, Error> {
        try streamCompletionRequest(payload)
    }

    func stream(request payload: ChatCompletionRequest) throws -> AsyncThrowingStream<String, Error> {
        try streamChatRequest(payload)
    }
}

public extension OpenAIClient {
    static func live(
        httpClient: StreamingHTTPClient = URLSession.shared,
        apiKey: String
    ) -> Self {
        let baseURL = URL(string: "https://api.openai.com/")!

        let encoder = apply(JSONEncoder()) {
            $0.keyEncodingStrategy = .convertToSnakeCase
        }
        let decoder = apply(JSONDecoder()) {
            $0.keyDecodingStrategy = .convertFromSnakeCase
        }

        func request(endpoint: String, method: String = "GET", body: (any Encodable)? = nil) throws -> URLRequest {
            var request = URLRequest(url: URL(string: endpoint, relativeTo: baseURL)!)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpMethod = method
            request.httpBody = try body.map { try encoder.encode($0) }
            return request
        }

        func parseResponse<T>(_ response: URLResponse, data: Data, _ type: T.Type) throws -> T where T: Decodable {
            guard let response = response as? HTTPURLResponse else { throw OpenAIError.unexpected  }

            do {
                if response.statusCode == 200 {
                    return try decoder.decode(type, from: data)
                } else {
                    let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
                    throw OpenAIError.remote(errorResponse.error)
                }
            } catch let error as OpenAIError {
                throw error // passthrough
            } catch let error as DecodingError {
                throw OpenAIError.decodingFailed(error)
            } catch {
                throw OpenAIError.unexpected
            }
        }

        return OpenAIClient(
            performCompletionRequest: { payload in
                let request = try request(endpoint: "/v1/completions", method: "POST", body: payload)
                let result = try await httpClient.data(for: request)
                return try parseResponse(result.1, data: result.0, CompletionResponse.self)
            },
            streamCompletionRequest: { payload in
                let request = try request(endpoint: "/v1/chat/completions", method: "POST", body: payload.streamed())
                return try httpClient.stream(for: request).map(MessageToTokenTransformer<CompletionResponse>(
                    getToken: \.choices.first?.text,
                    decoder: decoder
                ).callAsFunction).stream
            },
            streamChatRequest: { payload in
                let request = try request(endpoint: "/v1/chat/completions", method: "POST", body: payload.streamed())
                return try httpClient.stream(for: request).map(MessageToTokenTransformer<ChatCompletionResponseMessage>(
                    getToken: \.choices.first?.delta.content,
                    decoder: decoder
                ).callAsFunction).stream
            },
            performModelsRequest: {
                let result = try await httpClient.data(for: request(endpoint: "/v1/models"))
                return try parseResponse(result.1, data: result.0, ModelsResponse.self)
            }
        )
    }
}

public protocol StreamingHTTPClient: HTTPClient {
    func stream(for request: URLRequest) throws -> AsyncThrowingStream<String, Error>
}

public enum OpenAIError: Swift.Error {
    case remote(ErrorResponse.Error)
    case decodingFailed(DecodingError)
    case unexpected
}


public struct CompletionRequest: Codable {
    public let model: Model
    public let prompt: String
    public let maxTokens: Int?
    public let temperature: Float?
    var stream: Bool = false

    public init(model: Model, prompt: String, maxTokens: Int? = nil, temperature: Float? = nil) {
        self.model = model
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    func streamed() -> Self {
        var res = self
        res.stream = true
        return res
    }
}

public struct CompletionResponse: Codable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]

    public struct Choice: Codable, Equatable {
        public let text: String
        public let finishReason: String?

        public init(text: String, finishReason: String?) {
            self.text = text
            self.finishReason = finishReason
        }
    }

    public init(id: String, object: String, created: Int, model: String, choices: [Choice]) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }
}

public struct ModelsResponse: Codable, Equatable {
    public init() {

    }
}

public struct ChatMessage: Codable, Equatable {
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    public enum Role: String, Codable {
        case system
        case user
        case assistant
    }
}

public struct ChatCompletionRequest: Codable, Equatable {
    public let model: Model
    public var messages: [ChatMessage]
    public let maxTokens: Int?
    public let temperature: Float?
    var stream: Bool = false

    public init(model: Model = .gpt35Turbo, messages: [ChatMessage], maxTokens: Int? = nil, temperature: Float? = nil) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    func streamed() -> Self {
        var res = self
        res.stream = true
        return res
    }
}

public struct ChatCompletionResponseMessage: Codable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]

    public struct Choice: Codable, Equatable {
        public let delta: Delta
        public let finishReason: String?

        public struct Delta: Codable, Equatable {
            public let role: ChatMessage.Role?
            public let content: String?
        }
    }
}

public struct ErrorResponse: Codable {
    let error: Error

    public struct Error: Swift.Error, Codable {
        public let message: String
        public let type: String
        public let code: Code

        public enum Code: String, Codable {
            case invalidAPIKey = "invalid_api_key"
            case insufficientQuota = "insufficient_quota"
        }
    }
}
