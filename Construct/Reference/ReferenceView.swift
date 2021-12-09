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

struct ReferenceView: View {

    static let maxItems = 8

    let store: Store<ReferenceViewState, ReferenceViewAction>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            TabbedDocumentView(
                items: tabItems(viewStore),
                content: { item in
                    IfLetStore(store.scope(state: replayNonNil({ $0.items[id: item.id]?.state }), action: { .item(item.id, $0) }), then: ReferenceItemView.init)
                },
                selection: viewStore.binding(get: { $0.selectedItemId }, send: { .selectItem($0) }),
                onAdd: {
                    withAnimation {
                        viewStore.send(.onNewTabTapped)
                    }
                },
                onDelete: { tab in
                    withAnimation {
                        viewStore.send(.removeTab(tab))
                    }
                },
                onMove: { from, to in
                    viewStore.send(.moveTab(from, to))
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func tabItems(_ viewStore: ViewStore<ReferenceViewState, ReferenceViewAction>) -> [TabbedDocumentViewContentItem] {
        viewStore.items.suffix(Self.maxItems).map { item in
            TabbedDocumentViewContentItem(
                id: item.id,
                label: Label(item.title, systemImage: "doc")
            )
        }
    }
}
