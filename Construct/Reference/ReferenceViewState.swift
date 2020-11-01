//
//  ReferenceViewState.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct ReferenceViewState: Equatable {

    var items: IdentifiedArray<UUID, Item>
    var selectedItemId: UUID?

    init(items: IdentifiedArray<UUID, Item>) {
        self.items = items
        self.selectedItemId = items.first?.id
    }

    var selectedItemNavigationNode: NavigationNode? {
        get {
            selectedItemId.flatMap { items[id: $0]?.state.content.navigationNode }
        }
        set {
            guard let newValue = newValue else { return }
            guard let id = selectedItemId else { return }
            items[id: id]?.state.content.navigationNode = newValue
        }
    }

    struct Item: Equatable, Identifiable {
        let id = UUID()
        var title: String
        var state: ReferenceItemViewState

        init(title: String? = nil, state: ReferenceItemViewState) {
            self.title = title ?? state.content.tabItemTitle ?? "Untitled"
            self.state = state
        }

        mutating func updateTitle() {
            if let title = state.content.tabItemTitle {
                self.title = title
            }
        }

        static let reducer: Reducer<Item, ReferenceItemViewAction, Environment> = ReferenceItemViewState.reducer.pullback(state: \.state, action: /ReferenceItemViewAction.self)
    }

}

enum ReferenceViewAction: Equatable {
    case item(UUID, ReferenceItemViewAction)
    case onBackTapped
    case onNewTabTapped
    case removeTab(UUID)
    case selectItem(UUID?)
}

extension ReferenceViewState {
    static let reducer: Reducer<Self, ReferenceViewAction, Environment> = Reducer.combine(
        ReferenceViewState.Item.reducer.forEach(state: \.items, action: /ReferenceViewAction.item, environment: { $0 }),
        Reducer { state, action, env in
            switch action {
            case .item(let uuid, _):
                // update titles
                if let item = state.items[id: uuid], let title = item.state.content.tabItemTitle {
                    state.items[id: uuid]?.updateTitle()
                }
            case .onBackTapped:
                state.selectedItemNavigationNode?.popLastNavigationStackItem()
                if let id = state.selectedItemId {
                    state.items[id: id]?.updateTitle()
                }
            case .onNewTabTapped:
                let item = Item(state: ReferenceItemViewState())
                state.items.append(item)
                state.selectedItemId = item.id
            case .removeTab(let id):
                state.items.removeAll(where: { $0.id == id })
            case .selectItem(let id):
                state.selectedItemId = id ?? state.items.first?.id
            }
            return .none
        }
    )
}

extension ReferenceViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { return "ReferenceViewState" }
    var navigationTitle: String { return "Reference" }
}

extension ReferenceViewState {
    static let nullInstance = ReferenceViewState(items: [])
}
