//
//  CampaignBrowser.swift
//  Construct
//
//  Created by Thomas Visser on 10/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Persistence
import GameModels

class CampaignBrowser {
    /// The number of existing nodes (excluding root node) when the app is first opened
    static let initialSpecialNodeCount = 1

    let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
    }

    func nodes(in node: CampaignNode) throws -> [CampaignNode] {
        return try store.fetchAll(node.keyPrefixForFetchingDirectChildren)
    }

    func put(_ node: CampaignNode) throws {
        try store.put(node)
    }

    func remove(_ node: CampaignNode, recursive: Bool = true) throws {
        var nodes = [(node, false)]
        while let (next, didAddChildren) = nodes.popLast() {
            if !didAddChildren {
                let children = try self.nodes(in: next)
                nodes.append((next, true))
                nodes.append(contentsOf: children.map { ($0, false) })
            } else {
                if let contents = next.contents {
                    _ = try store.remove(contents.key)
                }
                _ = try store.remove(next.key)
            }
        }
    }

    func move(_ node: CampaignNode, to destination: CampaignNode) throws {
        var newNode = node
        newNode.parentKeyPrefix = destination.keyPrefixForChildren.rawValue

        try store.put(newNode)
        try store.remove(node.key)
    }

    /// Returns the total number of nodes
    func nodeCount() throws -> Int {
        return try store.count(CampaignNode.keyPrefix)
    }
}
