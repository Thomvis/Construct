//
//  CompendiumDataSourceReader.swift
//  SwiftUITest
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
    var progress: Progress { get } // FIXME not used
    var items: AnyPublisher<CompendiumItem, Error> { get }
}
