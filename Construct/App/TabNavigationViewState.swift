//
//  TabNavigationViewState.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct TabNavigationViewState: Equatable {

    var selectedTab: Tabs = .campaign

    var campaignBrowser: CampaignBrowseViewState = CampaignBrowseViewState(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
    var compendium: CompendiumIndexState = CompendiumIndexState(title: "Compendium", properties: .index, results: .initial)
    var diceRoller: DiceRollerViewState = DiceRollerViewState()

    var topNavigationItems: [Any] {
        switch selectedTab {
        case .campaign: return campaignBrowser.topNavigationItems()
        case .compendium: return compendium.topNavigationItems()
        case .diceRoller: return []
        }
    }

    enum Tabs: Int {
        case campaign
        case compendium
        case diceRoller
    }
}

enum TabNavigationViewAction: Equatable {
    case selectedTab(TabNavigationViewState.Tabs)
    case campaignBrowser(CampaignBrowseViewAction)
    case compendium(CompendiumIndexAction)
    case diceRoller(DiceRollerViewAction)
}

extension TabNavigationViewState {
    static let reducer: Reducer<Self, TabNavigationViewAction, Environment> = Reducer.combine(
        CampaignBrowseViewState.reducer.pullback(state: \.campaignBrowser, action: /TabNavigationViewAction.campaignBrowser),
        compendiumRootReducer.pullback(state: \.compendium, action: /TabNavigationViewAction.compendium),
        DiceRollerViewState.reducer.pullback(state: \.diceRoller, action: /TabNavigationViewAction.diceRoller),
        Reducer { state, action, env in
            switch action {
            case .selectedTab(let t):
                state.selectedTab = t
            case .campaignBrowser: break
            case .compendium: break
            case .diceRoller: break
            }
            return .none
        }
    )

    static let nullInstance = TabNavigationViewState(
        selectedTab: .campaign,
        campaignBrowser: .nullInstance,
        compendium: .nullInstance,
        diceRoller: .nullInstance
    )
}
