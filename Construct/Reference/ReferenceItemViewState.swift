//
//  ReferenceItemViewState.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths

struct ReferenceItemViewState: Equatable {

    var content: Content = .home(Content.Home(presentedScreens: [:]))

    var home: Content.Home? {
        get {
            guard case .home(let s) = content else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                content = .home(newValue)
            }
        }
    }

    var combatantDetail: Content.CombatantDetail? {
        get {
            guard case .combatantDetail(let s) = content else { return nil }
            return s
        }
        set {
            if let newValue = newValue {
                content = .combatantDetail(newValue)
            }
        }
    }

    enum Content: Equatable {
        case home(Home)
        case combatantDetail(CombatantDetail)

        struct Home: Equatable, NavigationStackSourceState {

            var navigationStackItemStateId: String = "home"
            var navigationTitle: String = "home"

            var presentedScreens: [NavigationDestination: NextScreen]

            var nextCompendium: CompendiumIndexState? {
                get { nextScreen?.navigationStackItemState as? CompendiumIndexState }
                set {
                    if let newValue = newValue {
                        nextScreen = .compendium(newValue)
                    }
                }
            }

            enum NextScreen: Equatable, NavigationStackItemStateConvertible, NavigationStackItemState {
                case compendium(CompendiumIndexState)

                var navigationStackItemState: NavigationStackItemState {
                    switch self {
                    case .compendium(let s): return s
                    }
                }
            }
        }

        struct CombatantDetail: Equatable {
            var encounter: Encounter // updated from the outside
            var selectedCombatantId: UUID

            var runningEncounter: RunningEncounter? {
                didSet {
                    if pinToTurn, let turn = runningEncounter?.turn {
                        selectedCombatantId = turn.combatantId
                    }
                }
            }

            var pinToTurn: Bool

            var detailState: CombatantDetailViewState

            init(encounter: Encounter, selectedCombatantId: UUID, runningEncounter: RunningEncounter?) {
                self.encounter = encounter
                self.selectedCombatantId = selectedCombatantId
                self.runningEncounter = runningEncounter

                self.pinToTurn = selectedCombatantId == runningEncounter?.turn?.combatantId

                let combatant = runningEncounter?.current.combatant(for: selectedCombatantId)
                    ?? encounter.combatant(for: selectedCombatantId)
                    ?? Combatant.nullInstance
                self.detailState = CombatantDetailViewState(runningEncounter: runningEncounter, combatant: combatant)
            }
        }
    }
}

enum ReferenceItemViewAction: Equatable {
    case contentHome(Home)
    case contentCombatantDetail(CombatantDetail)

    enum Home: Equatable, NavigationStackSourceAction {
        case setNextScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case nextScreen(NextScreenAction)
        case setDetailScreen(ReferenceItemViewState.Content.Home.NextScreen?)
        indirect case detailScreen(NextScreenAction)

        static func presentScreen(_ destination: NavigationDestination, _ screen: ReferenceItemViewState.Content.Home.NextScreen?) -> Self {
            switch destination {
            case .nextInStack: return .setNextScreen(screen)
            case .detail: return .setDetailScreen(screen)
            }
        }

        static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self {
            switch destination {
            case .nextInStack: return .nextScreen(action)
            case .detail: return .detailScreen(action)
            }
        }

        enum NextScreenAction: Equatable {
            case compendium(CompendiumIndexAction)
        }
    }

    enum CombatantDetail: Equatable {
        case detail(CombatantDetailViewAction)
    }
}

extension ReferenceItemViewState {
    static let nullInstance = ReferenceItemViewState()

    static let reducer: Reducer<Self, ReferenceItemViewAction, Environment> = Reducer.combine(
        ReferenceItemViewState.Content.Home.reducer.optional().pullback(state: \.home, action: /ReferenceItemViewAction.contentHome),
        ReferenceItemViewState.Content.CombatantDetail.reducer.optional().pullback(state: \.combatantDetail, action: /ReferenceItemViewAction.contentCombatantDetail)
    )
}

extension ReferenceItemViewState.Content.Home {
    static let reducer: Reducer<Self, ReferenceItemViewAction.Home, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.nextCompendium, action: /ReferenceItemViewAction.Home.nextScreen..ReferenceItemViewAction.Home.NextScreenAction.compendium),
        Reducer { state, action, env in
            switch action {
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .nextScreen: break // handled above
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .detailScreen: break // handled above
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.CombatantDetail {
    static let reducer: Reducer<Self, ReferenceItemViewAction.CombatantDetail, Environment> = Reducer.combine(
        CombatantDetailViewState.reducer.pullback(state: \.detailState, action: /ReferenceItemViewAction.CombatantDetail.detail)
    )
}
