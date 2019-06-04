//
//  ContentView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct ContentView: View {
    @EnvironmentObject var env: Environment
    var store: Store<AppState, AppState.Action>

    var body: some View {
        WithViewStore(store.scope(state: State.init)) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: { $0.selectedTab },
                    send: { AppState.Action.selectedTab($0) }
                )
            ) {
                CampaignBrowserContainerView(store: self.store)
                    .tabItem {
                        Image(systemName: "shield")
                        Text("Adventure")
                    }
                    .tag(AppState.Tabs.campaign)

                CompendiumContainerView(store: self.store)
                    .tabItem {
                        Image(systemName: "book")
                        Text("Compendium")
                    }
                    .tag(AppState.Tabs.compendium)

                DiceRollerView(store: self.store.scope(state: { $0.diceRoller }, action: { .diceRoller($0) }), isVisible: viewStore.selectedTab == .diceRoller)
                    .tabItem {
                        Image("tabbar_d20")
                        Text("Dice")
                    }
                    .tag(AppState.Tabs.diceRoller)
            }
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
                viewStore.send(.onAppear)
            }
        }
    }

    struct State: Equatable {
        var selectedTab: AppState.Tabs
        var showWelcomeSheet: Bool

        init(_ state: AppState) {
            self.selectedTab = state.selectedTab
            self.showWelcomeSheet = state.showWelcomeSheet
        }
    }
}
