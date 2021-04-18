//
//  FileDataSource.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

class FileDataSource: CompendiumDataSource {
    static let name = "FileDataSource"
    var bookmark: Data?

    private let result: AnyPublisher<Data, CompendiumDataSourceError>

    init(path: String, using fileManager: FileManager = FileManager.default) {
        self.bookmark = try? URL(fileURLWithPath: path).bookmarkData()
        self.result = Deferred { () -> AnyPublisher<Data, CompendiumDataSourceError> in
            do {
                let data = try NSData(contentsOfFile: path, options: [])
                return Just(data as Data).promoteError().eraseToAnyPublisher()
            } catch {
                return Fail(error: CompendiumDataSourceError.notFound).eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }

    func read() -> AnyPublisher<Data, CompendiumDataSourceError> {
        return result
    }

}
