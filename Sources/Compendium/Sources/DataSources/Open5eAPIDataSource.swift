//
//  Open5eAPIDataSource.swift
//  
//
//  Created by Thomas Visser on 15/06/2023.
//

import Foundation
import GameModels
import Helpers
import Tagged

public final class Open5eAPIDataSource: CompendiumDataSource {
    public static var name: String = "Open5eAPIDataSource"
    public var bookmark: String { url?.absoluteString ?? "unknown" }

    public let itemType: CompendiumItemType
    public let document: String?

    public let urlSession: URLSession

    var url: URL? {
        var urlComponents = URLComponents(string: "https://api.open5e.com/v1")
        switch itemType {
        case .monster:
            urlComponents?.path = "/monsters"
        case .spell:
            urlComponents?.path = "/spells"
        case .character, .group:
            return nil
        }

        if let document {
            urlComponents?.queryItems = [.init(name: "document__slug", value: document)]
        }

        return urlComponents?.url
    }

    public init(itemType: CompendiumItemType, document: String? = nil, urlSession: URLSession = URLSession.shared) {
        self.itemType = itemType
        self.document = document
        self.urlSession = urlSession
    }

    public func read() throws -> AsyncThrowingStream<[Open5eAPIResult], Swift.Error> {
        guard itemType == .monster || itemType == .spell else { throw Open5eAPIDataSourceError.unsupportedItemType }
        guard let initialURL = url else { throw Open5eAPIDataSourceError.illegalState }

        let decoder = JSONDecoder()

        return AsyncThrowingStream { continuation in
            let t = Task {
                do {
                    var nextURL: URL? = initialURL
                    while let url = nextURL {
                        let data = try await urlSession.data(from: url).0
                        let response = try decoder.decode(ListResponse.self, from: data)

                        continuation.yield(response.results)
                        nextURL = response.next.flatMap(URL.init)

                        if Task.isCancelled {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                t.cancel()
            }
        }
    }
}

enum Open5eAPIDataSourceError: Swift.Error {
    case unsupportedItemType
    case illegalState
    case allFailed([Swift.Error])
}

private struct ListResponse: Decodable {
    let next: String?
    let results: [Open5eAPIResult]
}

public typealias Open5eAPIResult = Either<O5e.Monster, O5e.Spell>
