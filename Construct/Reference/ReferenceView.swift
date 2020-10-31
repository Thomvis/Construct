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

    let store: Store<ReferenceViewState, ReferenceViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            TabbedDocumentView<ReferenceItemView>(
                items: tabItems(viewStore),
                selection: viewStore.binding(get: { $0.selectedItemId }, send: { .selectItem($0) }),
                _onDelete: {
                    viewStore.send(.removeTab($0))
                }
            )
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                    Button(action: {
                        withAnimation {
                            viewStore.send(.onNewTabTapped)
                        }
                    }) {
                        Label("New Tab", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: ToolbarItemPlacement.navigation) {
                    Button(action: {
                        viewStore.send(.onBackTapped)
                    }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled((viewStore.selectedItemNavigationNode?.navigationStackSize() ?? 0) <= 1)
                }
            }
            .navigationBarTitle("Reference", displayMode: .inline)
        }
    }

    func tabItems(_ viewStore: ViewStore<ReferenceViewState, ReferenceViewAction>) -> [TabbedDocumentView<ReferenceItemView>.ContentItem] {
        viewStore.items.map { item in
            TabbedDocumentView<ReferenceItemView>.ContentItem(
                id: item.id,
                label: Label("Item", systemImage: "book"),
                view: {
                    ReferenceItemView(store: store.scope(state: { $0.items[id: item.id]?.state ?? .nullInstance }, action: { .item(item.id, $0) }))
                }
            )
        }
    }
}
