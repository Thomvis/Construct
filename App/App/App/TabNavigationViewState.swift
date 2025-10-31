//
//  TabNavigationViewState.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import GameModels

struct TabNavigationViewState: Equatable {

    var selectedTab: Tabs = .campaign

    var campaignBrowser: CampaignBrowseViewState = CampaignBrowseViewState(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
    var compendium: CompendiumIndexFeature.State = CompendiumIndexFeature.State(
        title: "Compendium",
        properties: .init(
            showImport: true,
            showAdd: true,
            typeRestriction: nil
        ), results: .initial
    )
    var diceRoller: DiceRollerFeature.State = DiceRollerFeature.State()

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
    case compendium(CompendiumIndexFeature.Action)
    case diceRoller(DiceRollerFeature.Action)
}

extension TabNavigationViewState {
    public static let reducer: AnyReducer<Self, TabNavigationViewAction, Environment> = AnyReducer.combine(
        CampaignBrowseViewState.reducer.pullback(state: \.campaignBrowser, action: /TabNavigationViewAction.campaignBrowser),
        compendiumRootReducer.pullback(state: \.compendium, action: /TabNavigationViewAction.compendium),
        AnyReducer { env in
            DiceRollerFeature(environment: env)
        }
        .pullback(
            state: \.diceRoller,
            action: /TabNavigationViewAction.diceRoller,
            environment: { $0 }
        ),
        AnyReducer { state, action, env in
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
