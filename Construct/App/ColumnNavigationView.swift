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

    @State var didApplyPrimaryViewWorkAround = false

    var body: some View {
        ZStack {
            NavigationView {
                SidebarView(store: store.scope(state: { $0.sidebar }, action: { .sidebar($0) }))

                Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 200).opacity(0.66)

                Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 200).opacity(0.66)
            }
            .introspectViewController { vc in
                // workaround for an empty supplementary view on launch
                // the supplementary view is determined by the default selection inside the
                // primary view, but the primary view is not loaded so its selection is not read
                // We work around that by briefly showing the primary view.
                if !didApplyPrimaryViewWorkAround, let splitVC = vc.children.first as? UISplitViewController {
                    UIView.performWithoutAnimation {
                        splitVC.show(.primary)
                        splitVC.hide(.primary)
                    }
                    didApplyPrimaryViewWorkAround = true
                }
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
