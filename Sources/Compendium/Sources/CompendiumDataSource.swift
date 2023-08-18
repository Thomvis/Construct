//
//  CompendiumDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels
import Tagged

// Represents a source for compendium data, e.g. a local file or remote URL
public protocol CompendiumDataSource<Output> {
    associatedtype Output

    static var name: String { get }
    var bookmark: String { get }

    func read() throws -> AsyncThrowingStream<Output, Error>
}

private let compendiumDataSourceIdSeparator = "::"
public extension CompendiumDataSource {
    var id: CompendiumImportSourceId {
        .init(type: Self.name, bookmark: bookmark)
    }
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

public final class MapCompendiumDataSource<Source, Output>: CompendiumDataSource where Source: CompendiumDataSource {
    public static var name: String {
        "MapCompendiumDataSource<\(Source.name)>"
    }

    public var bookmark: String { source.bookmark }

    private var source: Source
    private var transform: (Source.Output) throws -> Output

    public init(source: Source, transform: @escaping (Source.Output) throws -> Output) {
        self.source = source
        self.transform = transform
    }

    public func read() throws -> AsyncThrowingStream<Output, Error> {
        try source.read().map(transform).stream
    }
}

public extension CompendiumDataSource {
    func map<NewOutput>(transform: @escaping (Output) throws -> NewOutput) -> some CompendiumDataSource<NewOutput> {
        MapCompendiumDataSource(source: self, transform: transform)
    }

    func decode<T: Decodable>(type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> some CompendiumDataSource<T> where Output == Data {
        MapCompendiumDataSource(source: self) { data in
            do {
                return try decoder.decode(type, from: data)
            } catch {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }
        }
    }
}
