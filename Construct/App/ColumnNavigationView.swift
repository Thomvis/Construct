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

    var splitVC = State<UISplitViewController?>(initialValue: nil)

    var body: some View {
        let placeholder = Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 400).opacity(0.66).blur(radius: 10)

        return ZStack {
            NavigationView {
                SidebarView(store: store.scope(state: { $0.sidebar }, action: { .sidebar($0) }))

                EmptyView()

                EmptyView()
            }
            .introspectViewController { vc in
                // workaround for an empty supplementary view on launch
                // the supplementary view is determined by the default selection inside the
                // primary view, but the primary view is not loaded so its selection is not read
                // We work around that by briefly showing the primary view.
                if !didApplyPrimaryViewWorkAround, let splitVC = vc.children.first as? UISplitViewController {
                    self.splitVC.wrappedValue = splitVC

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

            // workaround: hide the secondary view (i.e. reference view) when going to the compendium
            WithViewStore(store) { viewStore in
                Color.clear.onChange(of: viewStore.state.sidebar.presentedDetailCompendium != nil) { shouldHideReferenceView in
                    if shouldHideReferenceView, let nav = splitVC.wrappedValue?.viewController(for: .secondary) as? UINavigationController {
                        nav.setViewControllers([UIHostingController(rootView: placeholder)], animated: false)
                    }
                }
            }
        }
    }
}
