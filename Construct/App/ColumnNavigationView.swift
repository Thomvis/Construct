//
//  ColumnNavigationView.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import SwiftUI
import ComposableArchitecture

struct ColumnNavigationView: View {
    let store: Store<ColumnNavigationViewState, ColumnNavigationViewAction>

    var body: some View {
        ZStack {
            NavigationView {
                SidebarView(store: store.scope(state: { $0.sidebar }, action: { .sidebar($0) }))

                Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 200).opacity(0.66)

                Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 200).opacity(0.66)
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .environment(\.appNavigation, .column)

            FloatingDiceRollerContainerView(store: store.scope(
                state: { $0.diceCalculator },
                action: { .diceCalculator($0) }
            ))
        }
    }
}
