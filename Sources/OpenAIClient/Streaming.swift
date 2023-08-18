//
//  Streaming.swift
//  
//
//  Created by Thomas Visser on 10/02/2023.
//

import Foundation
import LDSwiftEventSource
import Helpers

extension EventSource.Config {
    init?(handler: EventHandler, request: URLRequest) {
        guard let url = request.url else { return nil }
        self.init(handler: handler, url: url)

        method = request.httpMethod ?? method
        headers = request.allHTTPHeaderFields ?? headers
        body = request.httpBody
    }
}

/**
 Sample response:

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": "\n", "index": 0, "logprobs": null, "finish_reason": null}], "model": "text-davinci-003"}

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": "\n", "index": 0, "logprobs": null, "finish_reason": null}], "model": "text-davinci-003"}

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": "The", "index": 0, "logprobs": null, "finish_reason": null}], "model": "text-davinci-003"}

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": " des", "index": 0, "logprobs": null, "finish_reason": null}], "model": "text-davinci-003"}

 ...

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": ".", "index": 0, "logprobs": null, "finish_reason": null}], "model": "text-davinci-003"}

 data: {"id": "cmpl-6ijluTRSwMuBIHsmXSR50mbeT80c1", "object": "text_completion", "created": 1676120398, "choices": [{"text": "", "index": 0, "logprobs": null, "finish_reason": "stop"}], "model": "text-davinci-003"}

 data: [DONE]
 */

struct MessageToTokenTransformer<Message> where Message: Decodable {
    let getToken: (Message) -> String?
    let decoder: JSONDecoder

    func callAsFunction(_ message: String) throws -> String {
        guard let data = message.data(using: .utf8) else { throw OpenAIError.unexpected }

        do {
            let message = try decoder.decode(Message.self, from: data)
            return getToken(message) ?? ""
        } catch let error as DecodingError {
            throw OpenAIError.decodingFailed(error)
        } catch {
            throw OpenAIError.unexpected
        }
    }
}

extension URLSession: StreamingHTTPClient {
    /// Known quirck: this method does actually not self, it creates a new URLSession instead
    /// Returns a stream of message event strings
    public func stream(for request: URLRequest) throws -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let config = EventSource.Config(
                handler: Handler(_onOpened: {

                }, _onClosed: {
                    continuation.finish()
                }, _onMessage: { type, event in
                    guard event.data != "[DONE]" else {
                        continuation.finish()
                        return
                    }

                    continuation.yield(event.data)
                }, _onComment: { comment in

                }, _onError: { error in
                    continuation.finish(throwing: error)
                }),
                request: request
            )
            guard let config else {
                continuation.finish(throwing: OpenAIError.unexpected)
                return
            }

            let source = EventSource(config: config)
            continuation.onTermination = { @Sendable _ in
                source.stop()
            }
            source.start()
        }
    }
}

/// Simple protocol witness for EventHandler
struct Handler: EventHandler {
    let _onOpened: () -> Void
    let _onClosed: () -> Void
    let _onMessage: (String, LDSwiftEventSource.MessageEvent) -> Void
    let _onComment: (String) -> Void
    let _onError: (Error) -> Void

    func onOpened() {
        _onOpened()
    }

    func onClosed() {
        _onClosed()
    }

    func onMessage(eventType: String, messageEvent: LDSwiftEventSource.MessageEvent) {
        _onMessage(eventType, messageEvent)
    }

    func onComment(comment: String) {
        _onComment(comment)
    }

    func onError(error: Error) {
        _onError(error)
    }
}
