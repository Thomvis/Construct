//
//  CombatantResourcesViewState.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 03/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct CombatantResourcesViewState: NavigationStackItemState, Equatable {
    var combatant: Combatant
    var editState: CombatantTrackerEditViewState?

    var navigationStackItemStateId: String {
        "\(combatant.id.rawValue.uuidString):CombatantResourcesViewState"
    }

    var navigationTitle: String { "Limited resources" }

    static let reducer: Reducer<Self, CombatantResourcesViewAction, Environment> = Reducer.combine(
        CombatantTrackerEditViewState.reducer.optional().pullback(state: \.editState, action: /CombatantResourcesViewAction.editState),
        Reducer { state, action, env in
            switch action {
            case .combatant: break // bubble-up
            case .setEditState(let s): state.editState = s
            case .editState(.onDoneTap):
                guard let res = state.editState?.resource else { return .none }
                state.editState = nil

                return Effect(value: .combatant(.addResource(res)))
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
