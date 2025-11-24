//
//  ReferenceView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Helpers

struct ReferenceView: View {

    static let maxItems = 8

    @Bindable var store: StoreOf<ReferenceViewFeature>

    var body: some View {
        TabbedDocumentView(
            items: tabItems(),
            content: { item in
                Group {
                    let itemStores = Array(store.scope(state: \.items, action: \.item))
                    if let itemStore = itemStores.first(where: { $0.withState { $0.id } == item.id }) {
                        ReferenceItemView(store: itemStore.scope(state: \.state, action: \.self))
                    }
                }
            },
            selection: Binding(
                get: { store.selectedItemId },
                set: { store.send(.selectItem($0)) }
            ),
            onAdd: {
                store.send(.onNewTabTapped, animation: .default)
            },
            onDelete: { tab in
                store.send(.removeTab(tab), animation: .default)
            },
            onMove: { from, to in
                store.send(.moveTab(from, to))
            }
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func tabItems() -> [TabbedDocumentViewContentItem] {
        store.items.suffix(Self.maxItems).map { item in
            TabbedDocumentViewContentItem(
                id: item.id,
                label: Label(item.title, systemImage: "doc")
            )
        }
    }
}
