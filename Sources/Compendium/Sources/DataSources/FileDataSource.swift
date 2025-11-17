//
//  FileDataSource.swift
//  Construct
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

public final class FileDataSource: CompendiumDataSource {
    public static let name = "FileDataSource"
    public let path: String
    public let fileManager: FileManager

    public var bookmark: String { path }

    public init(path: String, using fileManager: FileManager = FileManager.default) {
        self.path = path
        self.fileManager = fileManager
    }

    public func read() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            do {
                continuation.yield(try Data(contentsOf: URL(fileURLWithPath: path)))
                continuation.finish()
            } catch {
                continuation.finish(throwing: CompendiumDataSourceError.notFound)
            }
        }
    }

}
