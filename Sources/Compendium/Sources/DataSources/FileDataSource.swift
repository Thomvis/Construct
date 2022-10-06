//
//  FileDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

public class FileDataSource: CompendiumDataSource {
    public static let name = "FileDataSource"
    public var bookmark: Data?

    private let result: AnyPublisher<Data, CompendiumDataSourceError>

    public init(path: String, using fileManager: FileManager = FileManager.default) {
        self.bookmark = try? URL(fileURLWithPath: path).bookmarkData()
        self.result = Deferred { () -> AnyPublisher<Data, CompendiumDataSourceError> in
            do {
                let data = try NSData(contentsOfFile: path, options: [])
                return Just(data as Data).setFailureType(to: CompendiumDataSourceError.self).eraseToAnyPublisher()
            } catch {
                return Fail(error: CompendiumDataSourceError.notFound).eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }

    public func read() -> AnyPublisher<Data, CompendiumDataSourceError> {
        return result
    }

}
