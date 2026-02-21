//
//  FileDataSourceTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import Combine
import Compendium
import GameModels
@testable import Construct

class FileDataSourceTest: XCTestCase {
    func test() async throws {
        let sut = FileDataSource(path: defaultMonstersPath)

        let data = try await sut.read().first
        XCTAssertNotNil(data)
    }

    @MainActor
    func testSourceCreatedFromFileURLCanBeReadByXMLReader() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <compendium version="5">
          <monster>
            <name>Test Beast</name>
            <size>M</size>
            <type>beast</type>
            <ac>12</ac>
            <hp>7 (2d8)</hp>
            <speed>30 ft.</speed>
            <str>10</str>
            <dex>10</dex>
            <con>10</con>
            <int>2</int>
            <wis>12</wis>
            <cha>6</cha>
            <cr>1/8</cr>
          </monster>
        </compendium>
        """

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xml")
        try xml.data(using: .utf8)?.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let dataSourceState = CompendiumImportFeature.DataSource.State(
            title: "File",
            description: "",
            icon: .file,
            preferences: .file(.init(url: fileURL, openPicker: false))
        )
        guard let dataSource = dataSourceState.source as? FileDataSource else {
            XCTFail("Expected file data source")
            return
        }
        XCTAssertEqual(dataSource.path, fileURL.path)

        let reader = XMLCompendiumDataSourceReader(
            dataSource: dataSource,
            generateUUID: UUID.init
        )
        let items = try await Array(reader.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })
        XCTAssertEqual(items.count, 1)
    }
}
