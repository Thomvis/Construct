//
//  OpenAIClientTest.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation
import XCTest
import OpenAIClient
import CustomDump
import AsyncAlgorithms

final class OpenAIClientTest: XCTestCase {

    var httpClient: MockHTTPClient!
    var sut: OpenAIClient!

    override func setUp() {
        super.setUp()

        httpClient = MockHTTPClient()
        sut = OpenAIClient.live(httpClient: httpClient, apiKey: "XXX")
    }

    func testCompletion() async throws {
        // fake the response
        let responseData = """
        {"id":"cmpl-6JmBNcxha3k89zV2L6XzBXZdt5gb0","object":"text_completion","created":1670171465,"model":"text-davinci-003","choices":[{"text":"\\n\\nThis is indeed a test.","index":0,"logprobs":null,"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":8,"total_tokens":13}}
        """.data(using: .utf8)!
        httpClient.dataResponse = (responseData, HTTPURLResponse())

        let response = try await sut.perform(request: CompletionRequest(
            model: .Davinci3,
            prompt: "Say this is a test"
        ))

        // Assert serialized request
        let requestString = """
        {"model":"text-davinci-003","stream":false,"prompt":"Say this is a test"}
        """
        XCTAssertNoDifference((httpClient.dataRequests.last?.httpBody).map { String(data: $0, encoding: .utf8)}, requestString)

        // Assert parsed response
        XCTAssertNoDifference(response, CompletionResponse(
            id: "cmpl-6JmBNcxha3k89zV2L6XzBXZdt5gb0",
            object: "text_completion",
            created: 1670171465,
            model: "text-davinci-003",
            choices: [
                .init(text: "\n\nThis is indeed a test.", finishReason: "stop")
            ]
        ))
    }

    func testChatCompletion() async throws {
        // fake the response
        httpClient.streamResponse = [
            """
            {"id":"chatcmpl-6qJTvkR92tgHsu9nvdFSJSdhzk4yO","object":"chat.completion.chunk","created":1677925963,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"role":"assistant"},"index":0,"finish_reason":null}]}
            """,
            """
            {"id":"chatcmpl-6qJTvkR92tgHsu9nvdFSJSdhzk4yO","object":"chat.completion.chunk","created":1677925963,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"content":"As"},"index":0,"finish_reason":null}]}
            """,
            """
            {"id":"chatcmpl-6qJTvkR92tgHsu9nvdFSJSdhzk4yO","object":"chat.completion.chunk","created":1677925963,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"content":" the"},"index":0,"finish_reason":null}]}
            """
        ].async.stream

        let response = try sut.stream(request: ChatCompletionRequest(
            model: .gpt35Turbo,
            messages: [
                .init(role: .system, content: "You are a D&D DM"),
                .init(role: .user, content: "Narrate the attack of a goblin")
            ]
        ))

        // Assert serialized request
        let requestString = """
        {"model":"gpt-3.5-turbo","stream":true,"messages":[{"content":"You are a D&D DM","role":"system"},{"content":"Narrate the attack of a goblin","role":"user"}]}
        """
        XCTAssertNoDifference((httpClient.streamRequests.last?.httpBody).map { String(data: $0, encoding: .utf8)}, requestString)

        // Assert parsed response
        let string = try await response.reduce("", +)
        XCTAssertNoDifference(string, "As the")
    }

    class MockHTTPClient: HTTPClient {
        var dataResponse: (Data, URLResponse)?
        var dataRequests: [URLRequest] = []

        var streamResponse: AsyncThrowingStream<String, Error>?
        var streamRequests: [URLRequest] = []

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            await withUnsafeContinuation { continuation in
                dataRequests.append(request)
                continuation.resume(with: .success(dataResponse!))
            }
        }

        func stream(for request: URLRequest) throws -> AsyncThrowingStream<String, Error> {
            streamRequests.append(request)
            return streamResponse!
        }
    }

}
