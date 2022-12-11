//
//  ActionDescriptionViewState.swift
//  
//
//  Created by Thomas Visser on 10/12/2022.
//

import Foundation
import MechMuse
import Helpers
import Combine
import ComposableArchitecture
import GameModels

public struct ActionDescriptionViewState: Equatable {
    public typealias AsyncDescription = ResultSet<RequestInput?, String, Error>

    @BindableState var context: Context
    @BindableState var settings: Settings = .init(toneOfVoice: .gritty, outcome: .hit)

    private var description: AsyncDescription = .init(input: nil)
    private var cache: [RequestInput: String] = [:]

    public init(creature: StatBlock, action: CreatureAction) {
        self.context = .init(creature: creature, action: action)
    }

    var descriptionString: String? {
        description.value
    }

    var isLoadingDescription: Bool {
        description.result.isLoading
    }

    var effectiveOutcome: CreatureActionDescriptionRequest.Outcome {
        switch settings.outcome {
        case .hit:
            guard let action = context.diceAction else { return .averageHit }
            return .hit(.init(
                isCritical: action.isCriticalHit,
                damageDescription: action.damageDescription,
                attackImpact: .average // fixme
            ))
        case .miss:
            guard let action = context.diceAction else { return .miss }
            return .miss(action.isCriticalMiss)
        case .override(let o):
            return o
        }
    }

    struct Context: Equatable {
        let creature: StatBlock
        let action: CreatureAction
        var diceAction: DiceAction? = nil
        let encounter: Encounter? = nil
    }

    // configurable in this view
    struct Settings: Equatable {
        var toneOfVoice: ToneOfVoice
        var outcome: OutcomeSetting // can be used to override the outcome from the dice action

        enum OutcomeSetting: Hashable {
            case hit
            case miss
            case override(CreatureActionDescriptionRequest.Outcome)
        }

        var outcomeOverride: CreatureActionDescriptionRequest.Outcome? {
            get {
                guard case .override(let o) = outcome else { return nil }
                return o
            }
            set {
                if let newValue {
                    outcome = .override(newValue)
                }
            }
        }
    }

    public struct RequestInput: Hashable {
        var request: CreatureActionDescriptionRequest
        var toneOfVoice: ToneOfVoice
    }
}

public enum ActionDescriptionViewAction: Equatable, BindableAction {
    case onAppear
    case didRollDiceAction(DiceAction)
    case description(ActionDescriptionViewState.AsyncDescription.Action<ActionDescriptionViewInputAction>)
    case binding(BindingAction<ActionDescriptionViewState>)
}

public typealias ActionDescriptionEnvironment = EnvironmentWithMainQueue & EnvironmentWithMechMuse

public enum ActionDescriptionViewInputAction: Equatable, BindableAction {
    case binding(BindingAction<ActionDescriptionViewState.RequestInput>)
}

extension ActionDescriptionViewState.RequestInput {
    static var reducer: Reducer<Self, ActionDescriptionViewInputAction, ActionDescriptionEnvironment> = Reducer.combine().binding()
}

extension ActionDescriptionViewState {
    static var reducer: Reducer<Self, ActionDescriptionViewAction, ActionDescriptionEnvironment> = Reducer.combine(
        Reducer { state, action, env in
            switch action {
            case .onAppear: break
            case .didRollDiceAction(let a):
                state.context.diceAction = a
            case .description: break // handled by child reducer
            case .binding: break // handled by wrapper reducer
            }
            return .none
        },
        ResultSet<RequestInput?, String, Error>.reducer(ActionDescriptionViewState.RequestInput.reducer.binding().optional()) { input in
            return { env in
                return Future { promise in
                    Task {
                        guard let input else { promise(.failure(ActionDescriptionViewStateError.missingInput)); return }
                        do {
                            let description = try await env.mechMuse.describe(
                                action: input.request,
                                toneOfVoice: input.toneOfVoice
                            )
                            promise(.success(description))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
                .receive(on: env.mainQueue)
                .eraseToAnyPublisher()
            }
        }
        .pullback(state: \.description, action: /ActionDescriptionViewAction.description)
    )
    .binding()
    .onChange(of: \.input, perform: { input, state, action, env in
        if let cacheHit = state.cache[input] {
            // cache hit
            state.description.setValue(cacheHit, for: input)
            return .none
        } else {
            // trigger fetch
            return .task { .description(.setInput(input, debounce: false)) }
        }
    })
    // add results to the cache
    .onChange(of: { $0.description.result.value }, perform: { v, state, _, _ in
        if let value = v, let input = state.description.input {
            state.cache[input] = v
        }
        return .none
    })
    // clear cache if the context changes, because any change in settings won't ever result in a cache hit
    .onChange(of: \.context, perform: { _, state, _, _ in
        state.cache.removeAll()
        return .none
    })
}

extension ActionDescriptionViewState {
    fileprivate var input: RequestInput {
        return RequestInput(
            request: CreatureActionDescriptionRequest(
                creatureName: context.creature.name,
                isUniqueCreature: false, // todo
                creatureDescription: context.creature.subheading.nonEmptyString,
                creatureCondition: nil,
                encounter: context.encounter.map {
                    .init(name: $0.name, actionSetUp: nil)
                },
                actionName: context.action.name,
                actionDescription: context.action.description,
                outcome: effectiveOutcome
            ),
            toneOfVoice: settings.toneOfVoice
        )
    }
}

enum ActionDescriptionViewStateError: Swift.Error {
    case missingInput
}

fileprivate extension DiceAction {
    var isCriticalHit: Bool {
        steps.first { s in
            s.rollValue?.isToHit == true
        }?.rollValue?.result?.dice.first(where: { die in
            die.die == .d20
        })?.value == 20
    }

    var isCriticalMiss: Bool {
        steps.first { s in
            s.rollValue?.isToHit == true
        }?.rollValue?.result?.dice.first(where: { die in
            die.die == .d20
        })?.value == 1
    }

    var effects: [(Int, DamageType)] {
        steps.compactMap { step in
            guard case .damage(let d) = step.rollValue?.roll else { return nil }
            guard case let roll? = step.rollValue?.result else { return nil }
            return (roll.total, d.type)
        }
    }

    var damageDescription: String {
        let damageListFormatter = ListFormatter()
        damageListFormatter.locale = Locale(identifier: "en_US")

        let damageList = effects.map { "\($0.0) \($0.1.rawValue) damage" }
        return damageListFormatter.string(from: damageList) ?? CreatureActionDescriptionRequest.Outcome.averageHitDamageDescription
    }
}
