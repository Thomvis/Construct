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
import InterposeKit

struct ReferenceItemView: View {

    let store: Store<ReferenceItemViewState, ReferenceItemViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            NavigationViewHost {
                NavigationView {
                    Group {
                        IfLetStore(store.scope(state: { $0.home }, action: { .contentHome($0) }), then: HomeView.init)

                        IfLetStore(store.scope(state: { $0.combatantDetail }, action: { .contentCombatantDetail($0) }), then: CombatantDetailView.init)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
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

    struct CombatantDetailView: View {
        let store: Store<ReferenceItemViewState.Content.CombatantDetail, ReferenceItemViewAction.CombatantDetail>

        var body: some View {
            ZStack {
                WithViewStore(store) { viewStore in
                    Construct.CombatantDetailView(store: store.scope(state: { $0.detailState }, action: { .detail($0) }))
                        .id(viewStore.state.selectedCombatantId)

                    HStack {
                        Button(action: {
                            viewStore.send(.previousCombatantTapped)
                        }) {
                            Image(systemName: "chevron.left")
                        }

                        Button(action: {
                            viewStore.send(.togglePinToTurnTapped)
                        }) {
                            Image(systemName: viewStore.state.pinToTurn ? "pin.fill" : "pin.slash")
                        }
                        .disabled(viewStore.state.selectedCombatantId != viewStore.state.runningEncounter?.turn?.combatantId)

                        Button(action: {
                            viewStore.send(.nextCombatantTapped)
                        }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemGray4).cornerRadius(8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                }
            }
        }
    }
}

/// Fully disables the navigation bar of direct NavigationViews added to it
private struct NavigationViewHost<Content>: UIViewControllerRepresentable where Content: View {
    let content: () -> Content

    func makeUIViewController(context: Context) -> Host {
        Host(rootView: content())
    }

    func updateUIViewController(_ uiViewController: Host, context: Context) {

    }


    class Host: UIHostingController<Content> {
        override func addChild(_ childController: UIViewController) {
            super.addChild(childController)

            if let nav = childController as? UINavigationController {
                nav.isNavigationBarHidden = true
                try! nav.hook(
                    #selector(UINavigationController.setNavigationBarHidden(_:animated:)),
                    methodSignature: (@convention(c) (AnyObject, Selector, Bool, Bool) -> Void).self,
                    hookSignature: (@convention(block) (AnyObject, Bool, Bool) -> Void).self
                ) { store in
                    { `self`, hidden, animated in
                        // no-op
                    }
                }
            }
        }
    }
}
