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
                items[i].localState?.setContext(context)
            }
        }
    }
    var items: IdentifiedArray<UUID, Item>
    var selectedItemId: UUID?

    private(set) var remoteItemRequests: [RemoteReferenceViewItemRequest] = []

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

    mutating func updateRequests(remoteItemRequests: [RemoteReferenceViewItemRequest]) {
        var lastNewItem: UUID?
        for req in remoteItemRequests {
            let existing = items.first(where:  { $0.id == req.id })
            if let _ = existing {
                // todo
            } else {
                items.append(.remote(req.id, req.store.scope(state: { $0.state })))
                lastNewItem = req.id
            }
        }
        if let i = lastNewItem {
            selectedItemId = i
        }
        self.remoteItemRequests = remoteItemRequests

        // add default item if no other tabs
        if items.isEmpty {
            items.append(.local(Item.Local(state: Self.defaultItem)))
        }
    }

    enum Item: Equatable, Identifiable {
        case local(Local)
        case remote(UUID, Store<ReferenceItemViewState, ReferenceItemViewAction>)

        var id: UUID {
            switch self {
            case .local(let s): return s.id
            case .remote(let id, _): return id
            }
        }

        var title: String {
            state.content.tabItemTitle ?? ""
        }

        var state: ReferenceItemViewState {
            get {
                switch self {
                case .local(let s): return s.state
                case .remote(_, let s): return ViewStore(s).state
                }
            }
            set {
                switch self {
                case .local(let s): self = .local(Local(id: s.id, title: s.title, state: newValue))
                case .remote(_, let s):
                    DispatchQueue.main.async {
                        // work around recursive action, not great
                        ViewStore(s).send(.set(newValue))
                    }
                }
            }
        }

        var localState: ReferenceItemViewState? {
            get {
                if case .local(let s) = self {
                    return s.state
                }
                return nil
            }
            set {
                if let s = newValue, case .local(let l) = self {
                    self = .local(Local(id: l.id, title: l.title, state: s))
                }
            }
        }

        struct Local: Equatable {
            let id: UUID
            var title: String
            var state: ReferenceItemViewState

            init(id: UUID = UUID(), title: String? = nil, state: ReferenceItemViewState) {
                self.id = id
                self.title = title ?? state.content.tabItemTitle ?? "Untitled"
                self.state = state
            }
        }

        static let reducer: Reducer<Item, ReferenceItemViewAction, Environment> = ReferenceItemViewState.reducer.optional().pullback(state: \.localState, action: /ReferenceItemViewAction.self)

        static func ==(lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case (.local(let l), .local(let r)): return l == r
            case (.remote(let l, _), .remote(let r, _)): return l == r
            default: return false
            }
        }
    }

}

enum ReferenceViewAction: Equatable {
    case item(UUID, ReferenceItemViewAction)
    case onBackTapped
    case onNewTabTapped
    case removeTab(UUID)
    case selectItem(UUID?)

    case remoteItemRequests([RemoteReferenceViewItemRequest])
}

extension ReferenceViewState {
    static let reducer: Reducer<Self, ReferenceViewAction, Environment> = Reducer.combine(
        ReferenceViewState.Item.reducer.forEach(state: \.items, action: /ReferenceViewAction.item, environment: { $0 }),
        Reducer { state, action, env in
            switch action {
            case .item: break // handled above
            case .onBackTapped:
                state.selectedItemNavigationNode?.popLastNavigationStackItem()
            case .onNewTabTapped:
                let item = Item.local(Item.Local(state: ReferenceItemViewState(content: .home(ReferenceItemViewState.Content.Home(context: state.context)))))
                state.items.append(item)
                state.selectedItemId = item.id
            case .removeTab(let id):
                state.items.removeAll(where: { $0.id == id })
            case .selectItem(let id):
                state.selectedItemId = id ?? state.items.first?.id
            case .remoteItemRequests(let reqs):
                state.updateRequests(remoteItemRequests: reqs)
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
}
