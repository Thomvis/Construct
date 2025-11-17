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

    /// Legacy convenience used throughout the app. Equivalent to `navigationNodes`.
    func topNavigationItems() -> [Any] { navigationNodes }
}
