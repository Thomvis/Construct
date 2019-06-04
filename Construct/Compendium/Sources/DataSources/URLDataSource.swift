//
//  URLDataSource.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

class URLDataSource: CompendiumDataSource {
    static let name = "URLDataSource"
    var bookmark: Data? { url.data(using: .utf8) }

    let url: String
    let urlSession: URLSession

    init(url: String, using urlSession: URLSession = URLSession.shared) {
        self.url = url
        self.urlSession = urlSession
    }

    func read() -> AnyPublisher<Data, Error> {
        return urlSession.dataTaskPublisher(for: URL(string: url)!).map { data, response in
            return data
        }
        .mapError { $0 as Error }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

}
