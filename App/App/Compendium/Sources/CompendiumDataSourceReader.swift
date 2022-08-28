//
//  CompendiumDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

protocol CompendiumDataSourceReader {
    static var name: String { get }

    var dataSource: CompendiumDataSource { get }

    func read() -> CompendiumDataSourceReaderJob
}

protocol CompendiumDataSourceReaderJob {
    var output: AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError> { get }
}

enum CompendiumDataSourceReaderOutput {
    case item(CompendiumItem)
    case invalidItem(String?)

    var item: CompendiumItem? {
        guard case .item(let item) = self else { return nil }
        return item
    }
}

enum CompendiumDataSourceReaderError: LocalizedError {
    case dataSource(CompendiumDataSourceError)
    case incompatibleDataSource

    var errorDescription: String? {
        switch self {
        case .dataSource(let error): return error.localizedDescription
        case .incompatibleDataSource: return NSLocalizedString("Incompatible data source format", comment: "CompendiumDataSourceReaderError.incompatibleDataSource")
        }
    }
}