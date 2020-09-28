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
    var store: Store<ColumnNavigationViewState, ColumnNavigationViewAction>

    var body: some View {
        ZStack {
            Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 200).opacity(0.66)

            FloatingDiceRollerContainerView(store: store.scope(
                state: { $0.diceCalculator },
                action: { .diceCalculator($0) }
            ))
        }
    }
}
