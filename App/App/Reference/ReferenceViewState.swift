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

@Reducer
struct ReferenceViewFeature {

    @ObservableState
    struct State: Equatable {

        var encounterReferenceContext: EncounterReferenceContext? {
            didSet {
                for index in items.indices {
                    var item = items[index]
                    item.state.content.context.encounterDetailView = encounterReferenceContext
                    items[index] = item
                }
            }
        }

        var items: IdentifiedArray<TabbedDocumentViewContentItem.Id, Item.State>
        var selectedItemId: TabbedDocumentViewContentItem.Id?

        private(set) var itemRequests: [ReferenceViewItemRequest] = []

        init(items: IdentifiedArray<TabbedDocumentViewContentItem.Id, Item.State>) {
            self.items = items
            self.selectedItemId = items.first?.id
        }

        var selectedItemNavigationNodes: [Any]? {
            guard let id = selectedItemId else { return nil }
            return items[id: id]?.state.content.navigationNodes
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
                    items.append(Item.State(id: req.id, state: req.state))
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

        fileprivate func itemContext(for item: Item.State) -> ReferenceContext {
            itemContext(for: item, openCompendiumEntries: openCompendiumEntries())
        }

        fileprivate func itemContext(for item: Item.State, openCompendiumEntries: [(TabbedDocumentViewContentItem.Id, CompendiumEntry)]) -> ReferenceContext {
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
                .flatMap { item -> [(TabbedDocumentViewContentItem.Id, Any)] in
                    item.state.content.navigationNodes.map { (item.id, $0) }
                }
                .compactMap { (itemId, anyItem) -> (TabbedDocumentViewContentItem.Id, CompendiumEntry)? in
                    switch anyItem {
                    case let item as CompendiumEntryDetailFeature.State:
                        return (itemId, item.entry)
                    default:
                        return nil
                    }
                }
        }
    }

    enum Action: Equatable {
        case item(IdentifiedActionOf<Item>)
        case onBackTapped
        case onNewTabTapped
        case removeTab(TabbedDocumentViewContentItem.Id)
        case moveTab(Int, Int)
        case selectItem(TabbedDocumentViewContentItem.Id?)

        case itemRequests([ReferenceViewItemRequest])
    }

    @Reducer
    struct Item {
        typealias Action = ReferenceItem.Action

        @ObservableState
        struct State: Equatable, Identifiable {
            let id: TabbedDocumentViewContentItem.Id
            var title: String
            var state: ReferenceItem.State

            init(id: TabbedDocumentViewContentItem.Id = UUID().tagged(), title: String? = nil, state: ReferenceItem.State) {
                self.id = id
                self.title = title ?? state.content.tabItemTitle ?? "Untitled"
                self.state = state
            }
        }

        var body: some ReducerOf<Self> {
            Reduce<State, Action> { state, action in
                switch action {
                case .contentCombatantDetail, .contentCompendium, .contentAddCombatant, .contentCompendiumItem, .contentSafari, .onBackTapped, .set:
                    if let title = state.state.content.tabItemTitle {
                        state.title = title;
                    }
                case .inEncounterDetailContext, .close: break
                }
                return .none
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            case .onBackTapped:
                if let id = state.selectedItemId {
                    return .send(.item(.element(id: id, action: .onBackTapped)))
                }
            case .onNewTabTapped:
                var item = Item.State(state: ReferenceItem.State(content: .compendium(ReferenceItem.State.Content.Compendium())))
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
            case .item(.element(id: let id, action: .close)):
                return .send(.removeTab(id))
            case .item: break // handled above
            }
            return .none
        }
        .forEach(\.items, action: \.item) {
            Item()
        }

        Reduce<State, Action> { state, action in
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
    }

}

extension ReferenceViewFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String { return "ReferenceViewState" }
    var navigationTitle: String {
        return "Reference"
    }
}

extension ReferenceViewFeature.State: NavigationTreeNode {}

extension ReferenceViewFeature.State {
    static let nullInstance = Self(items: [])

    static let defaultInstance = Self(items: [.init(state: defaultItemState)])
    private static let defaultItemState = ReferenceItem.State(content: .compendium(ReferenceItem.State.Content.Compendium()))

    //Is this correct?
    var localStateForDeduplication: (TabbedDocumentViewContentItem.Id?, [ReferenceViewFeature.Item.State]) {
        (selectedItemId, items.map { item in
            if item.id == selectedItemId {
                var res = item
                res.state = ReferenceItem.State.nullInstance
                return res
            } else {
                return ReferenceViewFeature.Item.State(id: item.id, title: "", state: ReferenceItem.State.nullInstance)
            }
        })
    }
}
