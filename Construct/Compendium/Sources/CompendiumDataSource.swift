//
//  CompendiumDataSource.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

// Represents a source for compendium data, e.g. a local file or remote URL
protocol CompendiumDataSource {
    static var name: String { get }
    var bookmark: Data? { get }

    func read() -> AnyPublisher<Data, CompendiumDataSourceError>
}

enum CompendiumDataSourceError: Swift.Error {
    case notFound
    case other(Error)
}
