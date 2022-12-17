//
//  ActionResolutionViewState.swift
//  
//
//  Created by Thomas Visser on 08/12/2022.
//

import Foundation
import Helpers
import DiceRollerFeature
import ComposableArchitecture
import GameModels
import MechMuse

public struct ActionResolutionViewState: Equatable {
    let action: ParseableCreatureAction

    @BindableState var mode: Mode = .diceAction
    var diceAction: DiceActionViewState?
    var muse: ActionDescriptionViewState

    public init(creatureStats: StatBlock, action: ParseableCreatureAction) {
        self.action = action
        self.diceAction = (action.result?.value?.action).flatMap {
            DiceAction(title: action.name, parsedAction: $0)
        }.map {
            DiceActionViewState(
                creatureName: creatureStats.name,
                action: $0
            )
        }
        self.muse = .init(creature: creatureStats, action: action.input)
    }

    var heading: String {
        action.name
    }

    var subheading: String? {
        diceAction?.action.subtitle
    }

    enum Mode: Equatable {
        case diceAction
        case muse

        var toggled: Mode {
            switch self {
            case .diceAction: return .muse
            case .muse: return .diceAction
            }
        }

        var isMuse: Bool {
            if case .muse = self {
                return true
            }
            return false
        }
    }
}

public enum ActionResolutionViewAction: Equatable, BindableAction {
    case diceAction(DiceActionViewAction)
    case muse(ActionDescriptionViewAction)
    case binding(BindingAction<ActionResolutionViewState>)
}

public typealias ActionResolutionEnvironment = EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog & EnvironmentWithMechMuse

public extension ActionResolutionViewState {
    static var reducer: Reducer<Self, ActionResolutionViewAction, ActionResolutionEnvironment> = Reducer.combine(
        DiceActionViewState.reducer.optional()
            .pullback(state: \.diceAction, action: /ActionResolutionViewAction.diceAction),
        ActionDescriptionViewState.reducer.pullback(state: \.muse, action: /ActionResolutionViewAction.muse, environment: { $0 })
    )
    .binding()
    .onChange(of: \.mode) { mode, state, _, _ in
        if mode == .muse, let action = state.diceAction?.action {
            return .task { .muse(.didRollDiceAction(action))}
        }
        return .none
    }
}

public extension ActionResolutionViewState {
    static let nullInstance = ActionResolutionViewState(
        creatureStats: StatBlock.default,
        action: ParseableCreatureAction(input: CreatureAction(id: UUID(), name: "", description: ""))
    )
}