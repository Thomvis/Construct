//
//  ContentView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct ContentView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass

    @EnvironmentObject var env: Environment
    var store: Store<AppState, AppState.Action>

    var body: some View {
        #warning("fix removeDuplicates")
        WithViewStore(store) { viewStore in
            IfLetStore(store.scope(state: { $0.navigation.tabState }, action: { .navigation(.tab($0)) }), then: { store in
                TabNavigationView(store: store)
            }, else: IfLetStore(store.scope(state: { $0.navigation.columnState }, action: {.navigation(.column($0)) })) { store in
                ColumnNavigationView(store: store)
            })
            .sheet(isPresented: viewStore.binding(get: { $0.showWelcomeSheet }, send: { _ in .welcomeSheet(false) })) {
                WelcomeView { tap in
                    switch tap {
                    case .sampleEncounter:
                        viewStore.send(.welcomeSheetSampleEncounterTapped)
                    case .dismiss:
                        viewStore.send(.welcomeSheetDismissTapped)
                    }
                }
            }
            .onAppear {
                if let sizeClass = horizontalSizeClass {
                    viewStore.send(.navigation(.onHorizontalSizeClassChange(sizeClass)))
                }
                viewStore.send(.onAppear)
            }
            .onChange(of: horizontalSizeClass) { sizeClass in
                if let sizeClass = sizeClass {
                    viewStore.send(.navigation(.onHorizontalSizeClassChange(sizeClass)))
                }
            }
        }
    }
}
