//
//  ReferenceItemView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ReferenceItemView: View {

    let store: Store<ReferenceItemViewState, ReferenceItemViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            NavigationView {
                IfLetStore(store.scope(state: { $0.home }, action: { .contentHome($0) }), then: HomeView.init)
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    struct HomeView: View {
        let store: Store<ReferenceItemViewState.Content.Home, ReferenceItemViewAction.Home>

        var body: some View {
            WithViewStore(store) { viewStore in
                ScrollView {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text("Compendium").font(Font.title)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 24), count: 4)) {
                                Button(action: {
                                    viewStore.send(.setNextScreen(.compendium(CompendiumIndexState.init(title: "Monsters", properties: CompendiumIndexState.Properties.secondary, results: .initial(type: .monster)))))
                                }) {
                                    Text("Monsters")
                                }

                                Button(action: {
                                    viewStore.send(.setNextScreen(.compendium(CompendiumIndexState.init(title: "Characters", properties: CompendiumIndexState.Properties.secondary, results: .initial(type: .character)))))
                                }) {
                                    Text("Characters")
                                }

                                Button(action: {
                                    viewStore.send(.setNextScreen(.compendium(CompendiumIndexState.init(title: "Adventuring Parties", properties: CompendiumIndexState.Properties.secondary, results: .initial(type: .group)))))
                                }) {
                                    Text("Parties")
                                }

                                Button(action: {
                                    viewStore.send(.setNextScreen(.compendium(CompendiumIndexState.init(title: "Spells", properties: CompendiumIndexState.Properties.secondary, results: .initial(type: .spell)))))
                                }) {
                                    Text("Spells")
                                }
                            }
                        }
                        .buttonStyle(ButtonStyle())
                    }
                }
                .stateDrivenNavigationLink(
                    store: store,
                    state: /ReferenceItemViewState.Content.Home.NextScreenState.compendium,
                    action: /ReferenceItemViewAction.Home.NextScreenAction.compendium,
                    isActive: { _ in true },
                    destination: { CompendiumIndexView(store: $0) }
                )
            }
        }

        struct ButtonStyle: SwiftUI.ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(Font.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Color(UIColor.systemGray3)
                            .cornerRadius(8)
                    )
                    .opacity(configuration.isPressed ? 0.66 : 1.0)
            }
        }
    }
}
