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
    @SwiftUI.Environment(\.applyTestWorkaroundSidebarPresentation) var applyTestWorkaroundSidebarPresentation

    let store: Store<ColumnNavigationViewState, ColumnNavigationViewAction>

    @State var didApplyPrimaryViewWorkAround = false

    var splitVC = State<UISplitViewController?>(initialValue: nil)

    var body: some View {
        let placeholder = Image("icon").resizable().aspectRatio(contentMode: .fit).frame(width: 400).opacity(0.66).blur(radius: 10)

        return ZStack {
            NavigationView {
                SidebarView(store: store.scope(state: { $0.sidebar }, action: { .sidebar($0) }))

                if applyTestWorkaroundSidebarPresentation {
                    IfLetStore(store.scope(state: { $0.sidebar.presentedDetailCampaignBrowse }, action: { .sidebar(.detailScreen(.campaignBrowse($0))) }), then: { store in
                        CampaignBrowseTwoColumnContainerView(store: store)
                    }, else: IfLetStore(store.scope(state: { $0.sidebar.presentedDetailCompendium }, action: { .sidebar(.detailScreen(.compendium($0))) }), then: { store in
                        CompendiumIndexView(store: store)
                    }))
                } else {
                    EmptyView()
                }

                EmptyView()
            }
            .introspectViewController { vc in
                if let splitVC = vc.children.first as? UISplitViewController {
                    self.splitVC.wrappedValue = splitVC
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
                    guard let nav = splitVC.wrappedValue?.viewController(for: .secondary) as? UINavigationController else { return }
                    if shouldHideReferenceView {
                        nav.setViewControllers([UIHostingController(rootView: placeholder)], animated: false)
                    }
                }
            }
        }
    }
}
