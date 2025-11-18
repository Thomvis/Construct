//
//  NavigationTree.swift
//  Construct
//
//  Created by Thomas Visser on 17/11/2025.
//  Copyright ©
//

import Foundation
import SwiftUI

/// Retained to provide navigation ID/title metadata for sheets and other UI components.
public protocol NavigationStackItemState {
    var navigationStackItemStateId: String { get }
    var navigationTitle: String { get }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { get }
}

public extension NavigationStackItemState {
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { nil }
}

/// Describes state that participates in the app's navigation tree.
/// Conforming types can expose themselves (and any presented children)
/// so higher-level features (column/tab navigation, reference view, etc.)
/// can introspect the active navigation path.
public protocol NavigationTreeNode {
    /// All nodes that are currently active in the subtree rooted at `self`.
    /// The default implementation returns `[self]`.
    var navigationNodes: [Any] { get }
}

public extension NavigationTreeNode {
    var navigationNodes: [Any] { [self] }

    func navigationNodes<T>(of type: T.Type) -> [T] {
        navigationNodes.compactMap { $0 as? T }
    }

    func firstNavigationNode<T>(of type: T.Type) -> T? {
        navigationNodes(of: type).first
    }
}

/// Convenience for states that expose a single optional destination.
public protocol DestinationTreeNode: NavigationTreeNode {
    associatedtype DestinationState: NavigationTreeNode
    var destination: DestinationState? { get }
}

public extension DestinationTreeNode {
    var navigationNodes: [Any] {
        guard let destination else { return [self] }
        return [self] + destination.navigationNodes
    }
}
