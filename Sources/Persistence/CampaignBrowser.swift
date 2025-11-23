import Foundation
import GameModels
import ComposableArchitecture

public class CampaignBrowser {
    /// The number of existing nodes (excluding root node) when the app is first opened
    public static let initialSpecialNodeCount = 1

    public let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    public func nodes(in node: CampaignNode) throws -> [CampaignNode] {
        return try store.fetchAll(.keyPrefix(node.keyPrefixForFetchingDirectChildren))
    }

    public func put(_ node: CampaignNode) throws {
        try store.put(node)
    }

    public func remove(_ node: CampaignNode, recursive: Bool = true) throws {
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

    public func move(_ node: CampaignNode, to destination: CampaignNode) throws {
        var newNode = node
        newNode.parentKeyPrefix = destination.keyPrefixForChildren.rawValue

        try store.put(newNode)
        try store.remove(node.key)
    }

    /// Returns the total number of nodes
    public func nodeCount() throws -> Int {
        return try store.count(.keyPrefix(CampaignNode.keyPrefix))
    }
}

extension CampaignBrowser: DependencyKey {
    public static var liveValue: CampaignBrowser {
        @Dependency(\.database) var database
        return CampaignBrowser(store: database.keyValueStore)
    }
}

public extension DependencyValues {
    var campaignBrowser: CampaignBrowser {
        get { self[CampaignBrowser.self] }
        set { self[CampaignBrowser.self] = newValue }
    }
}

