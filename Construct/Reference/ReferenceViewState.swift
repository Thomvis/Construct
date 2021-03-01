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

    var context: EncounterReferenceContext? = nil {
        didSet {
            for i in items.indices {
                items[i].state.setContext(context)
            }
        }
    }
    var items: IdentifiedArray<UUID, Item>
    var selectedItemId: UUID?

    private(set) var itemRequests: [ReferenceViewItemRequest] = []

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

    mutating func updateRequests(itemRequests: [ReferenceViewItemRequest]) {
        var lastNewItem: UUID?

        var unmatchedItemRequests = self.itemRequests
        for req in itemRequests {
            let existing = items[id: req.id]
            unmatchedItemRequests.removeAll(where: { $0.id == req.id })
            if let _ = existing {
                let previousRequest = self.itemRequests.first(where: { $0.id == req.id })

                if previousRequest?.stateGeneration != req.stateGeneration {
                    items[id: req.id]?.state = req.state
                }

                if previousRequest?.focusRequest != req.focusRequest {
                    selectedItemId = req.id
                }
            } else {
                items.append(Item(id: req.id, state: req.state))
                lastNewItem = req.id
            }
        }

        // remove items that are no longer requested
        for req in unmatchedItemRequests {
            items.removeAll(where: { $0.id == req.id })
        }

        if let i = lastNewItem {
            selectedItemId = i
        }

        self.itemRequests = itemRequests

        // add default item if no other tabs
        if items.isEmpty {
            items.append(Item(state: Self.defaultItem))
        }
    }

    struct Item: Equatable, Identifiable {
        let id: UUID
        var title: String
        var state: ReferenceItemViewState

        init(id: UUID = UUID(), title: String? = nil, state: ReferenceItemViewState) {
            self.id = id
            self.title = title ?? state.content.tabItemTitle ?? "Untitled"
            self.state = state
        }

        static let reducer: Reducer<Item, ReferenceItemViewAction, Environment> = Reducer.combine(
            ReferenceItemViewState.reducer.pullback(state: \.state, action: /ReferenceItemViewAction.self),
            Reducer { state, action, env in
                switch action {
                case .contentCombatantDetail, .contentHome, .contentAddCombatant, .onBackTapped, .set:
                    if let title = state.state.content.tabItemTitle {
                        state.title = title;
                    }
                case .inContext: break
                }
                return .none
            }
        )
    }

}

enum ReferenceViewAction: Equatable {
    case item(UUID, ReferenceItemViewAction)
    case onBackTapped
    case onNewTabTapped
    case removeTab(UUID)
    case selectItem(UUID?)

    case itemRequests([ReferenceViewItemRequest])
}

extension ReferenceViewState {
    static let reducer: Reducer<Self, ReferenceViewAction, Environment> = Reducer.combine(
        ReferenceViewState.Item.reducer.forEach(state: \.items, action: /ReferenceViewAction.item, environment: { $0 }),
        Reducer { state, action, env in
            switch action {
            case .item: break // handled above
            case .onBackTapped:
                if let id = state.selectedItemId {
                    return .init(value: .item(id, .onBackTapped))
                }
            case .onNewTabTapped:
                let item = Item(state: ReferenceItemViewState(content: .home(ReferenceItemViewState.Content.Home(context: state.context))))
                state.items.append(item)
                state.selectedItemId = item.id
            case .removeTab(let id):
                state.items.removeAll(where: { $0.id == id })
            case .selectItem(let id):
                state.selectedItemId = id ?? state.items.first?.id
            case .itemRequests(let reqs):
                state.updateRequests(itemRequests: reqs)
            }
            return .none
        }
    )
}

extension ReferenceViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { return "ReferenceViewState" }
    var navigationTitle: String {
        if let singleItem = items.elements.single {
            return singleItem.title
        }
        return "Reference"
    }
}

extension ReferenceViewState {
    static let nullInstance = ReferenceViewState(items: [])

    static let defaultItem = ReferenceItemViewState(content: .home(ReferenceItemViewState.Content.Home()))

    //Is this correct?
    var normalizedForDeduplication: (UUID?, [Item]) {
        (selectedItemId, items.map { item in
            if item.id == selectedItemId {
                var res = item
                res.state = ReferenceItemViewState.nullInstance
                return res
            } else {
                return Item(id: item.id, title: "", state: ReferenceItemViewState.nullInstance)
            }
        })
    }
}
