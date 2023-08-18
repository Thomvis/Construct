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
    associatedtype Input

    static var name: String { get }

    var dataSource: any CompendiumDataSource<Input> { get }

    func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error>
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
