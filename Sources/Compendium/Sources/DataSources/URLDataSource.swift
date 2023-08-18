//
//  URLDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import Tagged

public final class URLDataSource: CompendiumDataSource {
    public static let name = "URLDataSource"
    public var bookmark: String { url }

    let url: String
    let urlSession: URLSession

    public init(url: String, using urlSession: URLSession = URLSession.shared) {
        self.url = url
        self.urlSession = urlSession
    }

    public func read() throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // do I really need a task here?
            let t = Task {
                do {
                    continuation.yield(try await urlSession.data(from: URL(string: url)!).0)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: CompendiumDataSourceError.other(error))
                }
            }
            continuation.onTermination = { _ in
                t.cancel()
            }
        }
    }

}
