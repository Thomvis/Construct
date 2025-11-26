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
    let store: StoreOf<CombatantResourcesFeature>

    var body: some View {
        ZStack {
            List {
                if store.combatant.resources.isEmpty {
                    Text("No resources")
                } else {
                    ForEach(store.combatant.resources, id: \.id) { resource in
                        HStack {
                            SimpleButton(action: {
                                store.send(.combatant(.removeResource(resource)))
                            }) {
                                Image(systemName: "minus.circle").font(Font.title.weight(.light)).foregroundColor(Color(UIColor.systemRed))
                            }

                            Text("\(resource.title) (\(resource.slots.count))")
                        }
                    }
                    .onDelete { indices in
                        let resources = store.combatant.resources
                        for i in indices {
                            store.send(.combatant(.removeResource(resources[i])))
                        }
                    }
                }

                EmptyView().padding(.bottom, 80)
            }

            HStack {
                RoundedButton(action: {
                    store.send(.setEditState(CombatantTrackerEditFeature.State(resource: CombatantResource(id: UUID().tagged(), title: "", slots: [false]))))
                }) {
                    Label("Add resource", systemImage: "plus.circle")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
        }
        .popover(Binding(get: { () -> AnyView? in
            if let editStore = store.scope(state: \.editState, action: \.editState) {
                return CombatantTrackerEditView(store: editStore).eraseToAnyView
            }
            return nil
        }, set: {
            if $0 == nil {
                store.send(.setEditState(nil))
            }
        }))
        .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
    }
}
