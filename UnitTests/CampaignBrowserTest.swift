//
//  CampaignBrowserTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 11/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class CampaignBrowserTest: XCTestCase {

    var store: KeyValueStore!

    override func setUp() {
        super.setUp()
        let db = try! Database(path: nil, importDefaultContent: false)
        self.store = db.keyValueStore
    }

    func testRootNodes() {
        let sut = CampaignBrowser(store: store)
        let node = CampaignNode(id: UUID().tagged(), title: "Test", contents: nil, special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)
        try! sut.put(node)

        let nodes = try! sut.nodes(in: CampaignNode.root)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].id, node.id)
    }

    func testNestedNodes() {
        let sut = CampaignBrowser(store: store)
        let groupInRoot = CampaignNode(id: UUID().tagged(), title: "Root Group", contents: nil, special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)
        let itemInRoot = CampaignNode(id: UUID().tagged(), title: "Root Item", contents: CampaignNode.Contents(key: "test", type: .encounter), special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)
        let rootGroupChildGroup = CampaignNode(id: UUID().tagged(), title: "Root Group Child Group", contents: nil, special: nil,  parentKeyPrefix: groupInRoot.keyPrefixForChildren)
        let rootGroupChildItem = CampaignNode(id: UUID().tagged(), title: "Root Group Child Item", contents: CampaignNode.Contents(key: "test2", type: .encounter), special: nil, parentKeyPrefix: groupInRoot.keyPrefixForChildren)
        let rootGroupChildItem2 = CampaignNode(id: UUID().tagged(), title: "Root Group Child Item 2", contents: CampaignNode.Contents(key: "test3", type: .encounter), special: nil, parentKeyPrefix: groupInRoot.keyPrefixForChildren)

        try! sut.put(rootGroupChildItem2)
        try! sut.put(rootGroupChildItem)
        try! sut.put(rootGroupChildGroup)
        try! sut.put(itemInRoot)
        try! sut.put(groupInRoot)

        XCTAssertEqual(try! sut.nodes(in: CampaignNode.root).map { $0.id.rawValue.uuidString }.sorted(), [groupInRoot.id.rawValue.uuidString, itemInRoot.id.rawValue.uuidString].sorted())
        XCTAssertEqual(try! sut.nodes(in: groupInRoot).map { $0.id.rawValue.uuidString}.sorted(), [rootGroupChildGroup.id.rawValue.uuidString, rootGroupChildItem.id.rawValue.uuidString, rootGroupChildItem2.id.rawValue.uuidString].sorted())
    }

    func testRemove() {
        let sut = CampaignBrowser(store: store)
        let groupInRoot = CampaignNode(id: UUID().tagged(), title: "Root Group", contents: nil, special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)
        let itemInRoot = CampaignNode(id: UUID().tagged(), title: "Root Item", contents: CampaignNode.Contents(key: "test", type: .encounter), special: nil, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)
        let rootGroupChildGroup = CampaignNode(id: UUID().tagged(), title: "Root Group Child Group", contents: nil, special: nil,  parentKeyPrefix: groupInRoot.keyPrefixForChildren)
        let rootGroupChildItem = CampaignNode(id: UUID().tagged(), title: "Root Group Child Item", contents: CampaignNode.Contents(key: "test2", type: .encounter), special: nil, parentKeyPrefix: groupInRoot.keyPrefixForChildren)
        let rootGroupChildItem2 = CampaignNode(id: UUID().tagged(), title: "Root Group Child Item 2", contents: CampaignNode.Contents(key: "test3", type: .encounter), special: nil, parentKeyPrefix: groupInRoot.keyPrefixForChildren)

        [groupInRoot, itemInRoot, rootGroupChildGroup, rootGroupChildItem, rootGroupChildItem2].forEach {
            try! sut.put($0)
        }

        try! sut.remove(groupInRoot, recursive: true)

        let topLevelNodes = try! sut.nodes(in: .root)
        XCTAssertEqual(topLevelNodes.count, 1)
        XCTAssertEqual(topLevelNodes[0].id, itemInRoot.id)
    }
}
