//
//  CompendiumDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels

public protocol CompendiumDataSourceReader {
    static var name: String { get }

    var dataSource: CompendiumDataSource { get }

    func makeJob() -> CompendiumDataSourceReaderJob
}

public protocol CompendiumDataSourceReaderJob {
    var output: AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> { get async throws }
}

public enum CompendiumDataSourceReaderOutput {
    case item(CompendiumItem)
    case invalidItem(String?)

    public var item: CompendiumItem? {
        guard case .item(let item) = self else { return nil }
        return item
    }
}

public enum CompendiumDataSourceReaderError: LocalizedError {
    case dataSource(CompendiumDataSourceError)
    case incompatibleDataSource

    public var errorDescription: String? {
        switch self {
        case .dataSource(let error): return error.localizedDescription
        case .incompatibleDataSource: return NSLocalizedString("Incompatible data source format", comment: "CompendiumDataSourceReaderError.incompatibleDataSource")
        }
    }
}
