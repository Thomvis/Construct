//
//  CombatantDetailColumnContainerViewState.swift
//  Construct
//
//  Created by Thomas Visser on 06/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct CombatantDetailColumnContainerViewState: Equatable {
    var encounter: Encounter
    var selectedCombatantId: UUID

    var runningEncounter: RunningEncounter? {
        didSet {
            if pinToTurn, let turn = runningEncounter?.turn {
                selectedCombatantId = turn.combatantId
            }
        }
    }

    var pinToTurn: Bool

    init(encounter: Encounter, selectedCombatantId: UUID, runningEncounter: RunningEncounter?) {
        self.encounter = encounter
        self.selectedCombatantId = selectedCombatantId
        self.runningEncounter = runningEncounter

        self.pinToTurn = selectedCombatantId == runningEncounter?.turn?.combatantId
    }


    var combatantDetailStates: IdentifiedArray<UUID, CombatantDetailViewState> {
        get {
            IdentifiedArray((runningEncounter?.current ?? encounter).combatantsInDisplayOrder.map {
                CombatantDetailViewState(
                    runningEncounter: runningEncounter,
                    combatant: $0
                )
            }, id: \.combatant.id)
        }
        set {
            // no-op, actions are processed by the parent
        }
    }
}

enum CombatantDetailSplitContainerViewAction: Equatable {
    case combatantDetail(UUID, CombatantDetailViewAction)
    case selectedCombatantId(UUID)
    case pinToTurn(Bool)
}

extension CombatantDetailColumnContainerViewState {
    static let reducer: Reducer<Self, CombatantDetailSplitContainerViewAction, Environment> = Reducer.combine(
            Reducer { state, action, _ in
            switch action {
            case .combatantDetail: break //handled below
            case .selectedCombatantId(let id):
                state.selectedCombatantId = id
                if id != state.runningEncounter?.turn?.combatantId {
                    state.pinToTurn = false
                }
            case .pinToTurn(let b):
                state.pinToTurn = b
            }
            return .none
        },
        CombatantDetailViewState.reducer.forEach(state: \.combatantDetailStates, action: /CombatantDetailSplitContainerViewAction.combatantDetail, environment: { $0 })
    )
}

extension CombatantDetailColumnContainerViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { "CombatantDetailSplitContainerViewState_\(encounter.id)" }
    var navigationTitle: String { "" }
}

extension CombatantDetailColumnContainerViewState {
    static let nullInstance = CombatantDetailColumnContainerViewState(encounter: Encounter.nullInstance, selectedCombatantId: Combatant.nullInstance.id, runningEncounter: nil)
}
