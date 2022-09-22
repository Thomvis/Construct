//
//  CombatantResourcesView.swift
//  Construct
//
//  Created by Thomas Visser on 03/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Tagged
import SharedViews

struct CombatantResourcesView: View {
    var store: Store<CombatantResourcesViewState, CombatantResourcesViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantResourcesViewState, CombatantResourcesViewAction>

    init(store: Store<CombatantResourcesViewState, CombatantResourcesViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var body: some View {
        ZStack {
            List {
                if viewStore.state.combatant.resources.isEmpty {
                    Text("No resources")
                } else {
                    ForEach(viewStore.state.combatant.resources, id: \.id) { resource in
                        HStack {
                            SimpleButton(action: {
                                self.viewStore.send(.combatant(.removeResource(resource)))
                            }) {
                                Image(systemName: "minus.circle").font(Font.title.weight(.light)).foregroundColor(Color(UIColor.systemRed))
                            }

                            Text("\(resource.title) (\(resource.slots.count))")
                        }
                    }
                    .onDelete { indices in
                        let resources = self.viewStore.state.combatant.resources
                        for i in indices {
                            self.viewStore.send(.combatant(.removeResource(resources[i])))
                        }
                    }
                }

                EmptyView().padding(.bottom, 80)
            }

            HStack {
                RoundedButton(action: {
                    self.viewStore.send(.setEditState(CombatantTrackerEditViewState(resource: CombatantResource(id: UUID().tagged(), title: "", slots: [false]))))
                }) {
                    Label("Add resource", systemImage: "plus.circle")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
        }
        .popover(Binding(get: { () -> AnyView? in
            if viewStore.state.editState != nil {
                return IfLetStore(store.scope(state: { $0.editState }, action: { .editState($0) })) { store in
                    CombatantTrackerEditView(store: store)
                }.eraseToAnyView
            }
            return nil
        }, set: {
            if $0 == nil {
                self.viewStore.send(.setEditState(nil))
            }
        }))
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
    }
}
