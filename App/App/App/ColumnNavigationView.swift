//
//  ColumnNavigationView.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import SwiftUI
import ComposableArchitecture
import Introspect

struct ColumnNavigationView: View {
    let store: Store<ColumnNavigationViewState, ColumnNavigationViewAction>

    var body: some View {
        return ZStack {
            HStack(spacing: 0) {
                CampaignBrowserContainerView(store: store.scope(state: { $0.campaignBrowse }, action: { .campaignBrowse($0) }))
                    .frame(width: 360)

                Divider().ignoresSafeArea()

                ReferenceView(store: store.scope(state: { $0.referenceView }, action: { .referenceView($0) }))
                    .zIndex(-1)
            }
            .environment(\.appNavigation, .column)

            FloatingDiceRollerContainerView(store: store.scope(
                state: { $0.diceCalculator },
                action: { .diceCalculator($0) }
            ))
        }
    }
}
