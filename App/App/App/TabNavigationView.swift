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
import TipKit

struct TabNavigationView: View {
    @Bindable var store: StoreOf<TabNavigationFeature>

    var body: some View {
        TabView(
            selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.selectedTab($0)) }
            )
        ) {
            adventureTabView
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

    @ViewBuilder
    var adventureTabView: some View {
        switch store.adventureTabMode {
        case .simpleEncounter:
            SimpleAdventureContainerView(
                store: store.scope(state: \.simpleAdventure, action: \.simpleAdventure)
            )
        case .campaignBrowser:
            CampaignBrowserContainerView(
                store: store.scope(state: \.campaignBrowser, action: \.campaignBrowser)
            ).task {
                await NormalModeTip.viewedNormalMode.donate()
            }
        }
    }
}

struct SimpleAdventureContainerView: View {
    var store: Store<SimpleAdventureFeature.State, SimpleAdventureFeature.Action>

    var body: some View {
        NavigationStack {
            SimpleAdventureView(store: store)
        }
    }
}

struct SimpleAdventureView: View {
    @Bindable var store: StoreOf<SimpleAdventureFeature>

    var body: some View {
        EncounterDetailView(store: store.scope(state: \.encounter, action: \.encounter))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Settings") {
                        store.send(.setSheet(.settings(SettingsFeature.State())))
                    }
                    .popoverTip(NormalModeTip(), arrowEdge: .top)
                }
            }
            .sheet(item: $store.scope(state: \.sheet, action: \.sheet)) { sheetStore in
                if let settingsStore = sheetStore.scope(state: \.settings, action: \.settings) {
                    SettingsContainerView(store: settingsStore)
                }
            }
            .onAppear {
                store.send(.onAppear)
                updateNormalModeTipParameters()
            }
            .onChange(of: store.shouldShowNormalModeTip) { _, _ in
                updateNormalModeTipParameters()
            }
    }

    private func updateNormalModeTipParameters() {
        NormalModeTip.runningEncounterCount = store.scratchPadRunningEncounterCount
    }
}

private struct NormalModeTip: Tip {
    @Parameter static var runningEncounterCount: Int = 0
    static var viewedNormalMode = Tips.Event(id: "normalModeDidOpen")

    var title: Text {
        Text("Need more encounters?")
    }

    var message: Text? {
        Text("Switch Adventure to Campaign browser in Settings.")
    }

    var image: Image? {
        Image(systemName: "square.stack.3d.up")
    }

    var rules: [Rule] {
        #Rule(Self.$runningEncounterCount) { $0 >= 3 }
        #Rule(Self.viewedNormalMode) { $0.donations.count == 0 }
    }
}
