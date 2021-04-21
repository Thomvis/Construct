//
//  Construct.swift
//  Construct
//
//  Created by Thomas Visser on 04/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct ConstructApp: App {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
//    @State var toggleNavigation = false

    @EnvironmentObject var env: Environment
    var store: Store<AppState, AppState.Action>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication }) { viewStore in
            IfLetStore(store.scope(state: { $0.navigation?.tabState }, action: { .navigation(.tab($0)) }), then: { store in
                TabNavigationView(store: store)
            }, else: IfLetStore(store.scope(state: { $0.navigation?.columnState }, action: {.navigation(.column($0)) })) { store in
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
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
                viewStore.send(.onAppear)
            }
            .onChange(of: horizontalSizeClass) { sizeClass in
                if let sizeClass = sizeClass {
                    viewStore.send(.onHorizontalSizeClassChange(sizeClass))
                }
            }
//            .overlay(ZStack {
//                Button(action: {
//                    self.toggleNavigation.toggle()
//                    let oppositeSizeClass: UserInterfaceSizeClass = horizontalSizeClass == .regular ? .compact : .regular
//                    viewStore.send(.onHorizontalSizeClassChange(toggleNavigation ? oppositeSizeClass : horizontalSizeClass!))
//                }) {
//                    Text("Toggle navigation")
//                }
//            })
        }
    }
}
