//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/07/2023.
//

import Foundation
import Helpers
import AsyncAlgorithms

public struct Open5eAPIClient {
    public typealias DocumentsResponse = PaginatedResource<Document>

    public let fetchDocuments: () async throws -> DocumentsResponse

    public init(fetchDocuments: @escaping () async throws -> DocumentsResponse) {
        self.fetchDocuments = fetchDocuments
    }

}

public struct PaginatedResource<Item> where Item: Decodable {
    let response: PaginatedResponse<Item>
    let fetchNext: (String?) async throws -> PaginatedResponse<Item>?

    public init(response: PaginatedResponse<Item>, fetchNext: @escaping (String?) async throws -> PaginatedResponse<Item>?) {
        self.response = response
        self.fetchNext = fetchNext
    }

    public var next: PaginatedResource<Item>? {
        get async throws {
            let response = try await fetchNext(response.next)
            guard let response else { return nil }

            return PaginatedResource(
                response: response,
                fetchNext: fetchNext
            )
        }
    }

    public var all: AsyncThrowingStream<Item, Error> {
        var current = self
        return chain(
            current.response.results.async,
            AsyncThrowingStream {
                guard let next = try await current.next else { return nil }
                current = next
                return next
            }.flatMap { (resource: PaginatedResource<Item>) in
                resource.response.results.async
            }
        ).stream
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<PaginatedResponse<Item>, T>) -> T {
        response[keyPath: keyPath]
    }
}

public extension Open5eAPIClient {
    static func live(
        httpClient: HTTPClient = URLSession.shared
    ) -> Self {
        let decoder = JSONDecoder()

        return Open5eAPIClient(fetchDocuments: {
            let fetch: ((String?) async throws -> PaginatedResponse<Document>?) = { next in
                guard let next else { return nil }

                let url = try URL(next, strategy: .url)
                var request = URLRequest(url: url)
                // Open5e intermittently responds with HTML unless we explicitly request JSON.
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Construct iOS", forHTTPHeaderField: "User-Agent")

                let (data, _) = try await httpClient.data(for: request)
                return try decoder.decode(PaginatedResponse<Document>.self, from: data)
            }

            let response = try await fetch("https://api.open5e.com/v2/documents/")
            guard let response = response else {
                fatalError()
            }
            return PaginatedResource(response: response, fetchNext: fetch)
        })
    }

}
