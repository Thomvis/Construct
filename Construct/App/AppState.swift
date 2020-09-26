//
//  AppState.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {

    var selectedTab: Tabs = .campaign

    var campaignBrowser: CampaignBrowseViewState = CampaignBrowseViewState(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
    var compendium: CompendiumIndexState = CompendiumIndexState(title: "Compendium", properties: .index, results: .initial)
    var diceRoller: DiceRollerViewState = DiceRollerViewState()

    var preferences: Preferences

    var showWelcomeSheet = false

    var sceneIsActive = false

    var topNavigationItemState: NavigationStackItemState? {
        guard !showWelcomeSheet else { return nil }
        switch selectedTab {
        case .campaign: return campaignBrowser.topNavigationItemState
        case .compendium: return compendium.topNavigationItemState
        case .diceRoller: return nil
        }
    }

    enum Tabs: Int {
        case campaign
        case compendium
        case diceRoller
    }

    enum Action: Equatable {
        case selectedTab(Tabs)
        case campaignBrowser(CampaignBrowseViewAction)
        case compendium(CompendiumIndexAction)
        case diceRoller(DiceRollerViewAction)
        case welcomeSheet(Bool)
        case welcomeSheetSampleEncounterTapped
        case welcomeSheetDismissTapped
        case onAppear

        case sceneDidBecomeActive
        case sceneWillResignActive

        var diceRollerAction: DiceRollerViewAction? {
            guard case .diceRoller(let a) = self else { return nil }
            return a
        }
    }

    static var reducer: Reducer<AppState, Action, Environment> {
        return Reducer.combine(
            Reducer { state, action, env in
                switch action {
                case .selectedTab(let t):
                    state.selectedTab = t
                case .campaignBrowser: break
                case .compendium: break
                case .diceRoller: break
                case .welcomeSheet(let show):
                    state.showWelcomeSheet = show
                    if !show {
                        state.preferences.didShowWelcomeSheet = true
                    }
                case .welcomeSheetSampleEncounterTapped:
                    return SampleEncounter.create(with: env)
                        .append(Effect.result { () -> Result<Action?, Never> in
                            // navigate to scratch pad
                            if let encounter: Encounter = try? env.database.keyValueStore.get(Encounter.key(Encounter.scratchPadEncounterId)) {
                                return .success(.campaignBrowser(.setNextScreen(.encounter(EncounterDetailViewState(building: encounter)))))
                            } else {
                                return .success(nil)
                            }
                        }.compactMap { $0 }.append(.welcomeSheet(false))).eraseToEffect()
                case .welcomeSheetDismissTapped:
                    return Effect(value: .welcomeSheet(false))
                case .onAppear:
                    if !state.preferences.didShowWelcomeSheet {
                        state.showWelcomeSheet = true
                    }
                case .sceneDidBecomeActive:
                    state.sceneIsActive = true
                case .sceneWillResignActive:
                    state.sceneIsActive = false
                }
                return .none
            },
            CampaignBrowseViewState.reducer.pullback(state: \.campaignBrowser, action: /Action.campaignBrowser),
            compendiumContainerReducer.pullback(state: \.compendium, action: /Action.compendium),
            DiceRollerViewState.reducer.pullback(state: \.diceRoller, action: /Action.diceRoller),
            Reducer { state, action, env in
                if state.sceneIsActive, let edv = state.topNavigationItemState as? EncounterDetailViewState, edv.running != nil {
                    env.isIdleTimerDisabled = true
                } else {
                    env.isIdleTimerDisabled = false
                }
                return .none
            }
        )
    }
}

protocol Popover {
    // if popoverId changes, it is considered a new popover
    var popoverId: AnyHashable { get }
    func makeBody() -> AnyView
}
