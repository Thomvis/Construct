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
import Persistence
import SwiftUI

public struct ActionResolutionViewState: Equatable {
    let encounterContext: EncounterContext?
    let action: ParseableCreatureAction
    private let preferences: Preferences

    @BindingState var mode: Mode = .diceAction
    var diceAction: DiceActionViewState?
    var muse: ActionDescriptionViewState

    public init(
        encounterContext: EncounterContext? = nil,
        creatureStats: StatBlock,
        action: ParseableCreatureAction,
        preferences: Preferences
    ) {
        self.encounterContext = encounterContext
        self.action = action
        self.preferences = preferences

        self.diceAction = (action.result?.value?.action).flatMap {
            DiceAction(title: action.name, parsedAction: $0)
        }.map {
            DiceActionViewState(
                creatureName: creatureStats.name,
                action: $0
            )
        }
        self.muse = .init(encounterContext: encounterContext, creature: creatureStats, action: action.input)
    }

    var heading: String {
        action.name
    }

    var subheading: String? {
        diceAction?.action.subtitle
    }

    var isMuseEnabled: Bool {
        preferences.mechMuse.enabled
    }

    public struct EncounterContext: Equatable {
        let encounter: Encounter?
        let combatant: Combatant

        public init(encounter: Encounter?, combatant: Combatant) {
            self.encounter = encounter
            self.combatant = combatant
        }
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

public typealias ActionResolutionEnvironment = EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog & EnvironmentWithMechMuse & EnvironmentWithSendMail

public extension ActionResolutionViewState {
    static var reducer: AnyReducer<Self, ActionResolutionViewAction, ActionResolutionEnvironment> = AnyReducer.combine(
        DiceActionViewState.reducer.optional()
            .pullback(state: \.diceAction, action: /ActionResolutionViewAction.diceAction),
        ActionDescriptionViewState.reducer.pullback(state: \.muse, action: /ActionResolutionViewAction.muse, environment: { $0 }),
        AnyReducer { state, action, env in
            switch action {
            case .diceAction(.onFeedbackButtonTap), .muse(.onFeedbackButtonTap):
                guard env.canSendMail() else { break }

                let currentState = state
                return .run { send in
                    let imageData = await MainActor.run {
                        let renderer = ImageRenderer(
                            content: ActionResolutionView(store: Store(
                                initialState: currentState,
                                reducer: .empty,
                                environment: env
                            ))
                        )

                        return renderer.uiImage?.pngData()
                    }

                    env.sendMail(.init(
                        subject: "Action Resolution Feedback",
                        attachment: Array(builder: {
                            FeedbackMailContents.Attachment(customDump: currentState)

                            if let imageData {
                                FeedbackMailContents.Attachment(data: imageData, mimeType: "image/png", fileName: "view.png")
                            }
                        })
                    ))
                }
            default: break
            }
            return .none
        }
    )
    .binding()
    .onChange(of: \.mode) { mode, state, _, _ in
        if mode == .muse, state.isMuseEnabled, let action = state.diceAction?.action {
            return .task { .muse(.didRollDiceAction(action)) }
        }
        return .none
    }
}

public extension ActionResolutionViewState {
    static let nullInstance = ActionResolutionViewState(
        creatureStats: StatBlock.default,
        action: ParseableCreatureAction(input: CreatureAction(id: UUID(), name: "", description: "")),
        preferences: Preferences()
    )
}
