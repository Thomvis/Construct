//
//  ActionResolutionFeature.State.swift
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

public struct ActionResolutionFeature: Reducer {

    let environment: ActionResolutionEnvironment

    public init(environment: ActionResolutionEnvironment) {
        self.environment = environment
    }

    public struct State: Equatable {
        let encounterContext: EncounterContext?
        let action: ParseableCreatureAction
        private let preferences: Preferences

        @BindingState var mode: Mode = .diceAction
        var diceAction: DiceActionFeature.State?
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
                DiceActionFeature.State(
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

    public enum Action: Equatable, BindableAction {
        case diceAction(DiceActionFeature.Action)
        case muse(ActionDescriptionViewAction)
        case binding(BindingAction<State>)
    }

    public var body: some ReducerProtocol<State, Action> {

        Scope(state: \.muse, action: /Action.muse) {
            Reduce(
                ActionDescriptionViewState.reducer,
                environment: environment
            )
        }

        Reduce { state, action in
            switch action {
            case .diceAction(.onFeedbackButtonTap), .muse(.onFeedbackButtonTap):
                guard environment.canSendMail() else { break }

                let currentState = state
                return .run { send in
                    let imageData = await MainActor.run {
                        let renderer = ImageRenderer(
                            content: ActionResolutionView(store: Store(
                                initialState: currentState,
                                reducer: .empty,
                                environment: environment
                            ))
                        )

                        return renderer.uiImage?.pngData()
                    }

                    environment.sendMail(.init(
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
        }.ifLet(\.diceAction, action: /Action.diceAction) {
            DiceActionFeature(environment: environment)
        }

        BindingReducer()
            .onChange(of: \.mode) { oldValue, newValue in
                Reduce { state, action in
                    if state.mode == .muse, state.isMuseEnabled, let action = state.diceAction?.action {
                        return .send(.muse(.didRollDiceAction(action)))
                    }
                    return .none
                }
            }
    }
}


public typealias ActionResolutionEnvironment = EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog & EnvironmentWithMechMuse & EnvironmentWithSendMail


public extension ActionResolutionFeature.State {
    static let nullInstance = Self(
        creatureStats: StatBlock.default,
        action: ParseableCreatureAction(input: CreatureAction(id: UUID(), name: "", description: "")),
        preferences: Preferences()
    )
}
