//
//  CompendiumDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

// Represents a source for compendium data, e.g. a local file or remote URL
public protocol CompendiumDataSource {
    static var name: String { get }
    var bookmark: Data? { get }

    func read() -> AnyPublisher<Data, CompendiumDataSourceError>
}

public enum CompendiumDataSourceError: LocalizedError {
    case notFound
    case other(Error)

    public var errorDescription: String? {
        switch self {
        case .notFound: return NSLocalizedString("Data source does not exist or could not be opened.", comment: "CompendiumDataSourceError.notFound")
        case .other(let error): return error.localizedDescription
        }
    }
}
