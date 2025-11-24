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
    @Bindable var store: StoreOf<TabNavigationFeature>

    var body: some View {
        TabView(
            selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.selectedTab($0)) }
            )
        ) {
            CampaignBrowserContainerView(store: store.scope(state: \.campaignBrowser, action: \.campaignBrowser))
                .tabItem {
                    Image(systemName: "shield")
                    Text("Adventure")
                }
                .tag(TabNavigationFeature.State.Tabs.campaign)

            CompendiumContainerView(store: store.scope(state: \.compendium, action: \.compendium))
                .tabItem {
                    Image(systemName: "book")
                    Text("Compendium")
                }
                .tag(TabNavigationFeature.State.Tabs.compendium)

            DiceRollerView(store: store.scope(state: \.diceRoller, action: \.diceRoller))
                .tabItem {
                    Image("tabbar_d20")
                    Text("Dice")
                }
                .tag(TabNavigationFeature.State.Tabs.diceRoller)
        }
        .environment(\.appNavigation, .tab)
    }
}
