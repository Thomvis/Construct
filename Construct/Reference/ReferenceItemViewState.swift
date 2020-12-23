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

        var combatantDetailState: CombatantDetail? {
            get {
                if case .combatantDetail(let s) = self {
                    return s
                }
                return nil
            }
            set {
                guard case .combatantDetail = self, let newValue = newValue else { return }
                self = .combatantDetail(newValue)
            }
        }

        var navigationNode: NavigationNode {
            get {
                switch self {
                case .home(let h): return h
                case .combatantDetail(let cd): return cd.detailState
                }
            }
            set {
                switch newValue {
                case let v as Home:
                    self = .home(v)
                case let v as CombatantDetailViewState:
                    self.combatantDetailState?.detailState = v
                default: break
                }
            }
        }

        var tabItemTitle: String? {
            navigationNode.topNavigationItems().compactMap({ $0 as? NavigationStackItemState }).first?.navigationTitle
        }

        struct Home: Equatable, NavigationStackSourceState {

            var navigationStackItemStateId: String = "home"
            var navigationTitle: String = "Favorites"

            var presentedScreens: [NavigationDestination: NextScreen]

            enum NextScreen: Equatable {
                case compendium(CompendiumIndexState)
            }
        }

        struct CombatantDetail: Equatable {
            var encounter: Encounter { // updated from the outside
                didSet {
                    updateDetailState()
                }
            }

            var selectedCombatantId: UUID {
                didSet {
                    updateDetailState()
                }
            }

            var runningEncounter: RunningEncounter? {
                didSet {
                    if pinToTurn, let turn = runningEncounter?.turn {
                        selectedCombatantId = turn.combatantId
                    }
                    updateDetailState()
                }
            }

            var effectiveEncounter: Encounter {
                runningEncounter?.current ?? self.encounter
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

            private mutating func updateDetailState() {
                if let combatant = effectiveEncounter.combatant(for: selectedCombatantId) {
                    detailState.combatant = combatant
                }
            }
        }
    }
}

enum ReferenceItemViewAction: Equatable {
    case contentHome(Home)
    case contentCombatantDetail(CombatantDetail)

    case set(ReferenceItemViewState)

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
        case previousCombatantTapped
        case nextCombatantTapped
        case togglePinToTurnTapped
    }
}

extension ReferenceItemViewState {
    static let nullInstance = ReferenceItemViewState()

    static let reducer: Reducer<Self, ReferenceItemViewAction, Environment> = Reducer.combine(
        ReferenceItemViewState.Content.Home.reducer.optional().pullback(state: \.home, action: /ReferenceItemViewAction.contentHome),
        ReferenceItemViewState.Content.CombatantDetail.reducer.optional().pullback(state: \.combatantDetail, action: /ReferenceItemViewAction.contentCombatantDetail),
        Reducer { state, action, env in
            switch action {
            case .set(let s): state = s
            case .contentCombatantDetail, .contentHome: break // handled below
            }
            return .none
        }
    )
}

extension ReferenceItemViewState.Content.Home {
    static let reducer: Reducer<Self, ReferenceItemViewAction.Home, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.presentedNextCompendium, action: /ReferenceItemViewAction.Home.nextScreen..ReferenceItemViewAction.Home.NextScreenAction.compendium),
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
        CombatantDetailViewState.reducer.pullback(state: \.detailState, action: /ReferenceItemViewAction.CombatantDetail.detail),
        Reducer { state, action, env in
            switch action {
            case .detail: break // handled above
            case .previousCombatantTapped:
                if let idx = state.effectiveEncounter.combatants.firstIndex(where: { $0.id == state.selectedCombatantId }), idx > 0 {
                    state.selectedCombatantId = state.effectiveEncounter.combatants[idx-1].id
                } else if let last = state.effectiveEncounter.combatants.last {
                    state.selectedCombatantId = last.id
                }
                break
            case .nextCombatantTapped:
                if let idx = state.effectiveEncounter.combatants.firstIndex(where: { $0.id == state.selectedCombatantId }), idx < state.effectiveEncounter.combatants.endIndex-1 {
                    state.selectedCombatantId = state.effectiveEncounter.combatants[idx+1].id
                } else if let first = state.effectiveEncounter.combatants.first {
                    state.selectedCombatantId = first.id
                }
            case .togglePinToTurnTapped:
                state.pinToTurn.toggle()
            }
            return .none
        }
    )
}
