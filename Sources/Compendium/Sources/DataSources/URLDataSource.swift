//
//  URLDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

public class URLDataSource: CompendiumDataSource {
    public static let name = "URLDataSource"
    public var bookmark: Data? { url.data(using: .utf8) }

    let url: String
    let urlSession: URLSession

    public init(url: String, using urlSession: URLSession = URLSession.shared) {
        self.url = url
        self.urlSession = urlSession
    }

    public func read() async throws -> Data {
        do {
            return try await urlSession.data(from: URL(string: url)!).0
        } catch {
            throw CompendiumDataSourceError.other(error)
        }
    }

}
