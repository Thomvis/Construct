//
//  OpenAIClient.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation
import Helpers

public class OpenAIClient {
    private let apiKey: String
    private let httpClient: HTTPClient

    private let encoder = apply(JSONEncoder()) {
        $0.keyEncodingStrategy = .convertToSnakeCase
    }

    private let decoder = apply(JSONDecoder()) {
        $0.keyDecodingStrategy = .convertFromSnakeCase
    }

    public init(apiKey: String, httpClient: HTTPClient) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public convenience init(apiKey: String, urlSession: URLSession = URLSession.shared) {
        self.init(
            apiKey: apiKey,
            httpClient: urlSession
        )
    }

    public func perform(request payload: CompletionRequest) async throws -> CompletionResponse {
        let request = try apply(URLRequest(url: URL(string: "https://api.openai.com/v1/completions")!)) { request in
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            request.httpBody = try encoder.encode(payload)
        }

        let result = try await httpClient.data(for: request)
        do {
            return try decoder.decode(CompletionResponse.self, from: result.0)
        } catch let error as DecodingError {
            print("Decoding of response failed. Response:\n\(String(data: result.0, encoding: .utf8))")
            throw error
        }
    }
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {

}

public struct CompletionRequest: Codable {
    public let model: Model
    public let prompt: String
    public let maxTokens: Int?
    public let temperature: Int?

    public init(model: Model, prompt: String, maxTokens: Int? = nil, temperature: Int? = nil) {
        self.model = model
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.temperature = temperature
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
        public let finishReason: String

        public init(text: String, finishReason: String) {
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
