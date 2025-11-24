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
    let store: StoreOf<ColumnNavigationFeature>

    var body: some View {
        return ZStack {
            HStack(spacing: 0) {
                CampaignBrowserContainerView(store: store.scope(state: \.campaignBrowse, action: \.campaignBrowse))
                    .frame(width: 360)

                Divider().ignoresSafeArea()

                ReferenceView(store: store.scope(state: \.referenceView, action: \.referenceView))
                    .zIndex(-1)
            }
            .environment(\.appNavigation, .column)

            FloatingDiceRollerContainerView(store: store.scope(
                state: \.diceCalculator,
                action: \.diceCalculator
            ))
        }
    }
}
