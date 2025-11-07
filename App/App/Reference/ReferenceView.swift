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

    let store: StoreOf<ReferenceViewFeature>

    var body: some View {
        WithViewStore(store, observe: \.self, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            TabbedDocumentView(
                items: tabItems(viewStore),
                content: { item in
                    IfLetStore(store.scope(state: replayNonNil({ $0.items[id: item.id]?.state }), action: { .item(item.id, $0) }), then: ReferenceItemView.init)
                },
                selection: viewStore.binding(get: { $0.selectedItemId }, send: { .selectItem($0) }),
                onAdd: {
                    viewStore.send(.onNewTabTapped, animation: .default)
                },
                onDelete: { tab in
                    viewStore.send(.removeTab(tab), animation: .default)
                },
                onMove: { from, to in
                    viewStore.send(.moveTab(from, to))
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func tabItems(_ viewStore: ViewStoreOf<ReferenceViewFeature>) -> [TabbedDocumentViewContentItem] {
        viewStore.items.suffix(Self.maxItems).map { item in
            TabbedDocumentViewContentItem(
                id: item.id,
                label: Label(item.title, systemImage: "doc")
            )
        }
    }
}
