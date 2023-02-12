//
//  Streaming.swift
//  
//
//  Created by Thomas Visser on 10/02/2023.
//

import Foundation
import LDSwiftEventSource

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
struct CompletionEventSource {
    let request: URLRequest
    let decoder: JSONDecoder

    func tokens() -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let config = EventSource.Config(
                handler: Handler(_onOpened: {

                }, _onClosed: {

                }, _onMessage: { type, event in
                    guard let data = event.data.data(using: .utf8) else { return }
                    guard let response = try? decoder.decode(CompletionResponse.self, from: data) else { return }
                    guard let choice = response.choices.first else { return }

                    continuation.yield(choice.text)

                    if choice.finishReason != nil {
                        continuation.finish()
                    }
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
