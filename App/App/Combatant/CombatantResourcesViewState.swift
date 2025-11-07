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

struct CombatantResourcesFeature: Reducer {
    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    struct State: NavigationStackItemState, Equatable {
        var combatant: Combatant
        var editState: CombatantTrackerEditFeature.State?

        var navigationStackItemStateId: String {
            "\(combatant.id.rawValue.uuidString):CombatantResourcesViewState"
        }

        var navigationTitle: String { "Limited resources" }

        static let nullInstance = State(combatant: Combatant.nullInstance, editState: nil)
    }

    enum Action: Equatable {
        case combatant(CombatantAction)
        case setEditState(CombatantTrackerEditFeature.State?)
        case editState(CombatantTrackerEditFeature.Action)

        var editStateAction: CombatantTrackerEditFeature.Action? {
            guard case .editState(let a) = self else { return nil }
            return a
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
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
        .ifLet(\.editState, action: /Action.editState) {
            CombatantTrackerEditFeature(environment: environment)
        }
    }
}

