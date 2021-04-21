//
//  CampaignBrowser.swift
//  Construct
//
//  Created by Thomas Visser on 10/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

class CampaignBrowser {
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
        newNode.parentKeyPrefix = destination.keyPrefixForChildren

        try store.put(newNode)
        try store.remove(node.key)
    }
}

extension CampaignNode: KeyValueStoreEntity {

}
