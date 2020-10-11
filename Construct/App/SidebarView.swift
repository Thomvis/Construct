//
//  SidebarView.swift
//  Construct
//
//  Created by Thomas Visser on 29/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct SidebarView: View {

    let store: Store<SidebarViewState, SidebarViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            List {
                Text("Test A")
                Text("Test B")
                Text("Test C")

                Section(header: Text("Compendium")) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /SidebarViewState.NextScreen.compendium,
                        action: /SidebarViewAction.NextScreenAction.compendium,
                        navDest: .detail,
                        isActive: { $0.title == "Monsters" }, // not great
                        initialState: CompendiumIndexState(title: "Monsters", properties: .secondary, results: .initial(type: .monster)),
                        destination: { CompendiumIndexView(store: $0) }
                    ) {
                        Text("Monsters")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Characters")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Adventuring Parties")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Spells")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Construct")
        }
    }
}
