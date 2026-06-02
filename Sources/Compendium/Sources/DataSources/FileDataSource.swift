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
                continuation.yield(try readData())
                continuation.finish()
            } catch let error as CompendiumDataSourceError {
                continuation.finish(throwing: error)
            } catch {
                continuation.finish(throwing: CompendiumDataSourceError.other(error))
            }
        }
    }

    private func readData() throws -> Data {
        let url = URL(fileURLWithPath: path)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<Data, Error>?

        coordinator.coordinate(readingItemAt: url, error: &coordinationError) { url in
            result = Result {
                try Data(contentsOf: url)
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        guard let result else {
            throw CompendiumDataSourceError.notFound
        }

        return try result.get()
    }

}
