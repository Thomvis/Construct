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

@Reducer
public struct ActionResolutionFeature {

    public init() { }

    @ObservableState
    public struct State: Equatable {
        let encounterContext: EncounterContext?
        let action: ParseableCreatureAction

        var mode: Mode = .diceAction
        var diceAction: DiceActionFeature.State?
        var muse: ActionDescriptionFeature.State
        var isMuseEnabled: Bool = false

        public init(
            encounterContext: EncounterContext? = nil,
            creatureStats: StatBlock,
            action: ParseableCreatureAction,
        ) {
            self.encounterContext = encounterContext
            self.action = action

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

        public struct EncounterContext: Equatable {
            let encounter: Encounter?
            let combatant: Combatant

            public init(encounter: Encounter?, combatant: Combatant) {
                self.encounter = encounter
                self.combatant = combatant
            }
        }

        public enum Mode: Equatable {
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

    public enum Action: Equatable {
        case onAppear
        case setMode(State.Mode)
        case diceAction(DiceActionFeature.Action)
        case muse(ActionDescriptionFeature.Action)
    }

    @Dependency(\.mailer) var mailer
    @Dependency(\.mechMuse) var mechMuse

    public var body: some Reducer<State, Action> {

        Scope(state: \.muse, action: \.muse) {
            ActionDescriptionFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isMuseEnabled = mechMuse.isConfigured
            case .setMode(let mode):
                state.mode = mode
                if state.mode == .muse, state.isMuseEnabled, let action = state.diceAction?.action {
                    return .send(.muse(.didRollDiceAction(action)))
                }
            case .diceAction(.onFeedbackButtonTap), .muse(.onFeedbackButtonTap):
                guard mailer.canSendMail() else { break }

                let currentState = state
                return .run { send in
                    let imageData = await MainActor.run {
                        let renderer = ImageRenderer(
                            // FIXME
                            content: ActionResolutionView(store: Store(
                                initialState: currentState
                            ) {
                                EmptyReducer()
                            })
                        )

                        return renderer.uiImage?.pngData()
                    }

                    mailer.sendMail(.init(
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
        }.ifLet(\.diceAction, action: \.diceAction) {
            DiceActionFeature()
        }
    }
}

public extension ActionResolutionFeature.State {
    static let nullInstance = Self(
        creatureStats: StatBlock.default,
        action: ParseableCreatureAction(input: CreatureAction(id: UUID(), name: "", description: ""))
    )
}
