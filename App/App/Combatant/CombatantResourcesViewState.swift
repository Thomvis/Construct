//
//  CombatantResourcesViewState.swift
//  Construct
//
//  Created by Thomas Visser on 03/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Helpers
import GameModels

struct CombatantResourcesViewState: NavigationStackItemState, Equatable {
    var combatant: Combatant
    var editState: CombatantTrackerEditViewState?

    var navigationStackItemStateId: String {
        "\(combatant.id.rawValue.uuidString):CombatantResourcesViewState"
    }

    var navigationTitle: String { "Limited resources" }

    static let reducer: AnyReducer<Self, CombatantResourcesViewAction, Environment> = AnyReducer.combine(
        CombatantTrackerEditViewState.reducer.optional().pullback(state: \.editState, action: /CombatantResourcesViewAction.editState),
        AnyReducer { state, action, env in
            switch action {
            case .combatant: break // bubble-up
            case .setEditState(let s): state.editState = s
            case .editState(.onDoneTap):
                guard let res = state.editState?.resource else { return .none }
                state.editState = nil

                return .send(.combatant(.addResource(res)))
            case .editState: break // handled below
            }
            return .none
        }
    )
}

enum CombatantResourcesViewAction: Equatable {
    case combatant(CombatantAction)
    case setEditState(CombatantTrackerEditViewState?)
    case editState(CombatantTrackerEditViewAction)

    var editStateAction: CombatantTrackerEditViewAction? {
        guard case .editState(let a) = self else { return nil }
        return a
    }
}

extension CombatantResourcesViewState {
    static let nullInstance = CombatantResourcesViewState(combatant: Combatant.nullInstance, editState: nil)
}
