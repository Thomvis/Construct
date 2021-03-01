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
                        IfLetStore(store.scope(state: { $0.content.homeState }, action: { .contentHome($0) }), then: HomeView.init)

                        IfLetStore(store.scope(state: { $0.content.combatantDetailState }, action: { .contentCombatantDetail($0) }), then: CombatantDetailView.init)

                        IfLetStore(store.scope(state: { $0.content.addCombatantState }, action: { .contentAddCombatant($0) }), then: AddCombatantReferenceItemView.init)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
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
