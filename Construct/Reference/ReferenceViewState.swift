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

    struct Item: Equatable, Identifiable {
        let id = UUID()
        var state: ReferenceItemViewState

        static let reducer: Reducer<Item, ReferenceItemViewAction, Environment> = ReferenceItemViewState.reducer.pullback(state: \.state, action: /ReferenceItemViewAction.self)
    }

}

enum ReferenceViewAction: Equatable {
    case item(UUID, ReferenceItemViewAction)
    case onNewTabTapped
    case removeTab(UUID)
}

extension ReferenceViewState {
    static let reducer: Reducer<Self, ReferenceViewAction, Environment> = Reducer.combine(
        ReferenceViewState.Item.reducer.forEach(state: \.items, action: /ReferenceViewAction.item, environment: { $0 }),
        Reducer { state, action, env in
            switch action {
            case .item: break;
            case .onNewTabTapped:
                let item = Item(state: ReferenceItemViewState())
                state.items.append(item)
            case .removeTab(let id):
                state.items.removeAll(where: { $0.id == id })
            }
            return .none
        }
    )
}
