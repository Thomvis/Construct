//
//  TabNavigationView.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import DiceRollerFeature

struct TabNavigationView: View {
    @EnvironmentObject var env: Environment
    var store: Store<TabNavigationViewState, TabNavigationViewAction>

    var body: some View {
        WithViewStore(store, observe: \.self, removeDuplicates: { $0.selectedTab == $1.selectedTab }) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: { $0.selectedTab },
                    send: { TabNavigationViewAction.selectedTab($0) }
                )
            ) {
                CampaignBrowserContainerView(store: store.scope(state: { $0.campaignBrowser }, action: { .campaignBrowser($0) }))
                    .tabItem {
                        Image(systemName: "shield")
                        Text("Adventure")
                    }
                    .tag(TabNavigationViewState.Tabs.campaign)

                CompendiumContainerView(store: store.scope(state: { $0.compendium }, action: { .compendium($0) }))
                    .tabItem {
                        Image(systemName: "book")
                        Text("Compendium")
                    }
                    .tag(TabNavigationViewState.Tabs.compendium)

                DiceRollerView(store: self.store.scope(state: { $0.diceRoller }, action: { .diceRoller($0) }))
                    .tabItem {
                        Image("tabbar_d20")
                        Text("Dice")
                    }
                    .tag(TabNavigationViewState.Tabs.diceRoller)
            }
            .environment(\.appNavigation, .tab)
        }
    }
}
