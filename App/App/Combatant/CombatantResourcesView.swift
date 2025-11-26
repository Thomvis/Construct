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
import GameModels

struct CombatantResourcesView: View {
    var store: Store<CombatantResourcesFeature.State, CombatantResourcesFeature.Action>
    @ObservedObject var viewStore: ViewStore<CombatantResourcesFeature.State, CombatantResourcesFeature.Action>

    init(store: Store<CombatantResourcesFeature.State, CombatantResourcesFeature.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
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
                    self.viewStore.send(.setEditState(CombatantTrackerEditFeature.State(resource: CombatantResource(id: UUID().tagged(), title: "", slots: [false]))))
                }) {
                    Label("Add resource", systemImage: "plus.circle")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
        }
        .popover(Binding(get: { () -> AnyView? in
            if store.editState != nil {
                let editStore = store.scope(state: \.editState!, action: \.editState)
                return CombatantTrackerEditView(store: editStore).eraseToAnyView
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
