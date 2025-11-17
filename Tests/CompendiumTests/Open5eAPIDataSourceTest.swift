//
//  Open5eAPIDataSourceTest.swift
//  
//
//  Created by Thomas Visser on 15/06/2023.
//

import Foundation
import Compendium
import XCTest

final class Open5eAPIDataSourceTest: XCTestCase {
    func test() async throws {
        let sut = Open5eAPIDataSource(itemType: .monster, document: "tob")
        for try await _ in try sut.read() {

        }
    }
}
