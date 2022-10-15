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
    public let path: String
    public let fileManager: FileManager
    public var bookmark: Data?

    public init(path: String, using fileManager: FileManager = FileManager.default) {
        self.path = path
        self.fileManager = fileManager

        self.bookmark = try? URL(fileURLWithPath: path).bookmarkData()
    }

    public func read() async throws -> Data {
        do {
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw CompendiumDataSourceError.notFound
        }
    }

}
