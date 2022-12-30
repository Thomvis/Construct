//
//  OpenAIClient.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation
import Helpers

/// Errors thrown by public functions are always of type `OpenAIError`
public class OpenAIClient {
    private static let baseURL = URL(string: "https://api.openai.com/")!

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
        return try parseResponse(result.1, data: result.0, CompletionResponse.self)
    }

    public func performModelsRequest() async throws -> ModelsResponse {
        let result = try await httpClient.data(for: request(endpoint: "/v1/models"))
        return try parseResponse(result.1, data: result.0, ModelsResponse.self)
    }

    private func request(endpoint: String, method: String = "GET", body: (any Encodable)? = nil) throws -> URLRequest {
        var request = URLRequest(url: URL(string: endpoint, relativeTo: Self.baseURL)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = method
        request.httpBody = try body.map { try encoder.encode($0) }
        return request
    }

    private func parseResponse<T>(_ response: URLResponse, data: Data, _ type: T.Type) throws -> T where T: Decodable {
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
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {

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

public struct ModelsResponse: Codable, Equatable {

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
