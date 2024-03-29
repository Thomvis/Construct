//
//  ReferenceViewState.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Helpers
import GameModels

struct ReferenceViewState: Equatable {

    var encounterReferenceContext: EncounterReferenceContext? {
        didSet {
            for item in items {
                items[id: item.id]?.state.content.context.encounterDetailView = encounterReferenceContext
            }
        }
    }

    var items: IdentifiedArray<TabbedDocumentViewContentItem.Id, Item>
    var selectedItemId: TabbedDocumentViewContentItem.Id?

    private(set) var itemRequests: [ReferenceViewItemRequest] = []

    init(items: IdentifiedArray<TabbedDocumentViewContentItem.Id, Item>) {
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
        var lastNewItem: TabbedDocumentViewContentItem.Id?

        var unmatchedItemRequests = self.itemRequests
        for req in itemRequests {
            let existingItem = items[id: req.id]
            let existingRequest = unmatchedItemRequests.first { $0.id == req.id }
            unmatchedItemRequests.removeAll(where: { $0.id == req.id })
            if !req.oneOff, existingItem != nil {
                let previousRequest = self.itemRequests.first(where: { $0.id == req.id })

                if previousRequest?.stateGeneration != req.stateGeneration {
                    items[id: req.id]?.state = req.state
                }

                if previousRequest?.focusRequest != req.focusRequest {
                    selectedItemId = req.id
                }
            } else if existingItem == nil && (!req.oneOff || existingRequest == nil) {
                items.append(Item(id: req.id, state: req.state))
                lastNewItem = req.id
            }
        }

        // remove items that are no longer requested
        for req in unmatchedItemRequests where !req.oneOff {
            items.removeAll(where: { $0.id == req.id })
        }

        if let i = lastNewItem {
            selectedItemId = i
        }

        self.itemRequests = itemRequests
    }

    fileprivate mutating func updateSelectionForRemovalOfCurrentItem() {
        if let idx = items.firstIndex(where: { $0.id == selectedItemId }) {
            if idx < items.count - 1 {
                selectedItemId = items[idx+1].id
            } else if idx > 0 {
                selectedItemId = items[idx-1].id
            } else {
                selectedItemId = nil
            }
        }
    }

    fileprivate func itemContext(for item: Item) -> ReferenceContext {
        itemContext(for: item, openCompendiumEntries: openCompendiumEntries())
    }

    fileprivate func itemContext(for item: Item, openCompendiumEntries: [(TabbedDocumentViewContentItem.Id, CompendiumEntry)]) -> ReferenceContext {
        ReferenceContext(
            encounterDetailView: encounterReferenceContext,
            openCompendiumEntries: openCompendiumEntries.compactMap { (itemId, entry) -> CompendiumEntry? in
                guard itemId != item.id else { return nil }
                return entry
            }
        )
    }

    fileprivate func openCompendiumEntries() -> [(TabbedDocumentViewContentItem.Id, CompendiumEntry)] {
        items
            .flatMap { item -> [(TabbedDocumentViewContentItem.Id, Any)] in item.state.content.navigationNode.topNavigationItems().map { (item.id, $0) } }
            .compactMap { (itemId, anyItem) -> (TabbedDocumentViewContentItem.Id, CompendiumEntry)? in
                switch anyItem {
                case let item as CompendiumEntryDetailViewState:
                    return (itemId, item.entry)
                default:
                    return nil
                }
            }
    }

    struct Item: Equatable, Identifiable {
        let id: TabbedDocumentViewContentItem.Id
        var title: String
        var state: ReferenceItemViewState

        init(id: TabbedDocumentViewContentItem.Id = UUID().tagged(), title: String? = nil, state: ReferenceItemViewState) {
            self.id = id
            self.title = title ?? state.content.tabItemTitle ?? "Untitled"
            self.state = state
        }

        static let reducer: AnyReducer<Item, ReferenceItemViewAction, Environment> = AnyReducer.combine(
            ReferenceItemViewState.reducer.pullback(state: \.state, action: /ReferenceItemViewAction.self),
            AnyReducer { state, action, env in
                switch action {
                case .contentCombatantDetail, .contentCompendium, .contentAddCombatant, .contentCompendiumItem, .contentSafari, .onBackTapped, .set:
                    if let title = state.state.content.tabItemTitle {
                        state.title = title;
                    }
                case .inEncounterDetailContext, .close: break
                }
                return .none
            }
        )
    }

}

enum ReferenceViewAction: Equatable {
    case item(TabbedDocumentViewContentItem.Id, ReferenceItemViewAction)
    case onBackTapped
    case onNewTabTapped
    case removeTab(TabbedDocumentViewContentItem.Id)
    case moveTab(Int, Int)
    case selectItem(TabbedDocumentViewContentItem.Id?)

    case itemRequests([ReferenceViewItemRequest])
}

extension ReferenceViewState {
    static let reducer: AnyReducer<Self, ReferenceViewAction, Environment> = AnyReducer.combine(
        ReferenceViewState.Item.reducer.forEach(state: \.items, action: /ReferenceViewAction.item, environment: { $0 }),
        AnyReducer { state, action, env in
            switch action {
            case .onBackTapped:
                if let id = state.selectedItemId {
                    return .init(value: .item(id, .onBackTapped))
                }
            case .onNewTabTapped:
                var item = Item(state: ReferenceItemViewState(content: .compendium(ReferenceItemViewState.Content.Compendium())))
                item.state.content.context = state.itemContext(for: item)
                state.items.append(item)
                state.selectedItemId = item.id
            case .removeTab(let id):
                if state.selectedItemId == id {
                    state.updateSelectionForRemovalOfCurrentItem()
                }
                state.items.removeAll(where: { $0.id == id })

                if state.items.isEmpty {
                    return .send(.onNewTabTapped)
                }
            case .moveTab(let from, let to):
                state.items.move(fromOffsets: IndexSet(integer: from), toOffset: to)
            case .selectItem(let id):
                state.selectedItemId = id ?? state.items.first?.id
            case .itemRequests(let reqs):
                state.updateRequests(itemRequests: reqs)

                if !state.items.contains(where: { $0.id == state.selectedItemId }) {
                    state.selectedItemId = state.items.first?.id
                }
            case .item(let id, .close):
                return .send(.removeTab(id))
            case .item: break // handled above
            }
            return .none
        },
        AnyReducer { state, action, env in
            switch action {
            // actions that can affect the open compendium entries
            case .item, .onBackTapped, .removeTab, .itemRequests:
                let entries = state.openCompendiumEntries()
                for item in state.items {
                    state.items[id: item.id]?.state.content.context.openCompendiumEntries = entries.compactMap { (itemId, entry) -> CompendiumEntry? in
                        guard itemId != item.id else { return nil }
                        return entry
                    }
                }
            // actions that don't affect the open compendium entries
            case .onNewTabTapped, .moveTab, .selectItem: break
            }

            return .none
        }
    )
}

extension ReferenceViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { return "ReferenceViewState" }
    var navigationTitle: String {
        return "Reference"
    }
}

extension ReferenceViewState {
    static let nullInstance = ReferenceViewState(items: [])

    static let defaultInstance = ReferenceViewState(items: [.init(state: defaultItemState)])
    private static let defaultItemState = ReferenceItemViewState(content: .compendium(ReferenceItemViewState.Content.Compendium()))

    //Is this correct?
    var localStateForDeduplication: (TabbedDocumentViewContentItem.Id?, [Item]) {
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
