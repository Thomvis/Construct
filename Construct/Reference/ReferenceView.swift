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
        WithViewStore(store, removeDuplicates: { $0.normalizedForDeduplication == $1.normalizedForDeduplication }) { viewStore in
            TabbedDocumentView(
                items: tabItems(viewStore),
                content: { item in
                    IfLetStore(store.scope(state: replayNonNil({ $0.items[id: item.id]?.state }), action: { .item(item.id, $0) }), then: ReferenceItemView.init)
                },
                selection: viewStore.binding(get: { $0.selectedItemId }, send: { .selectItem($0) }),
                onDelete: { tab in
                    withAnimation {
                        viewStore.send(.removeTab(tab))
                    }
                },
                onMove: { from, to in
                    viewStore.send(.moveTab(from, to))
                }
            )
            .environment(\.appNavigation, .tab)
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                    Button(action: {
                        withAnimation {
                            viewStore.send(.onNewTabTapped)
                        }
                    }) {
                        Label("New Tab", systemImage: "plus")
                    }
                    .disabled(viewStore.state.items.count >= Self.maxItems)
                }
            }
            .navigationBarTitle(viewStore.state.navigationTitle, displayMode: .inline)
        }
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
