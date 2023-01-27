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
        httpClient.response = (responseData, URLResponse())

        let response = try await sut.perform(request: CompletionRequest(
            model: .Davinci3,
            prompt: "Say this is a test"
        ))

        // Assert serialized request
        let requestString = """
        {"model":"text-davinci-003","prompt":"Say this is a test"}
        """
        XCTAssertEqual((httpClient.requests.last?.httpBody).map { String(data: $0, encoding: .utf8)}, requestString)

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

    class MockHTTPClient: HTTPClient {
        var response: (Data, URLResponse)?
        var requests: [URLRequest] = []

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            await withUnsafeContinuation { continuation in
                requests.append(request)
                continuation.resume(with: .success(response!))
            }
        }
    }

}
