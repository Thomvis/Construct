//
//  ActionDescriptionFeature.swift
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

public struct ActionDescriptionFeature: Reducer {

    let environment: ActionDescriptionEnvironment

    public init(environment: ActionDescriptionEnvironment) {
        self.environment = environment
    }

    public struct State: Equatable {
        public typealias _AsyncDescription_Reduce = AsyncReduce<String, String, MechMuseError>
        public typealias _AsyncDescription_Map = Map<RequestInput, _AsyncDescription_Reduce>
        public typealias AsyncDescription = Retain<_AsyncDescription_Map, _AsyncDescription_Reduce.State>

        let encounterContext: ActionResolutionFeature.State.EncounterContext?
        @BindingState var context: Context
        @BindingState var settings: Settings = .init(outcome: nil, impact: .average)

        fileprivate var description: AsyncDescription.State = .init(
            wrapped: .init(input: .init(), result: .init(value: ""))
        )
        fileprivate var cache: [RequestInput.State: _AsyncDescription_Reduce.State] = [:]
        fileprivate var mechMuseIsConfigured = true

        init(
            encounterContext: ActionResolutionFeature.State.EncounterContext? = nil,
            creature: StatBlock,
            action: CreatureAction
        ) {
            self.encounterContext = encounterContext
            self.context = Context(creature: creature, action: action)
        }

        var descriptionString: String? {
            let res = description.retained?.value ?? description.wrapped.result.value
            return res.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyString
        }

        var descriptionErrorString: AttributedString? {
            guard mechMuseIsConfigured else { return MechMuseError.unconfigured.attributedDescription }
            guard let error = description.wrapped.result.error else { return nil }
            return error.attributedDescription
        }

        var isLoadingDescription: Bool {
            description.result.isReducing
        }

        var didFailLoading: Bool {
            description.wrapped.result.error != nil
        }

        var isMissingOutcomeSetting: Bool {
            settings.outcome == nil
        }

        var effectiveOutcome: CreatureActionDescriptionRequest.Outcome? {
            guard let outcome = settings.outcome else { return nil }
            switch outcome {
            case .hit:
                guard let action = context.diceAction else { return .averageHit }
                return .hit(.init(
                    isCritical: action.isCriticalHit,
                    damageDescription: action.damageDescription,
                    attackImpact: settings.impact
                ))
            case .miss:
                guard let action = context.diceAction else { return .miss }
                return .miss(action.isCriticalMiss)
            }
        }

        var hitOrMissString: String? {
            guard let effectiveOutcome else { return nil }

            switch effectiveOutcome {
            case .hit(let h) where h.isCritical == true: return "Critical Hit"
            case .hit: return "Hit"
            case .miss(true): return "Critical Miss"
            case .miss(false): return "Miss"
            }
        }

        var impactString: String {
            switch settings.impact {
            case .minimal: return "Minimal"
            case .average: return "Average"
            case .devastating: return "Devastating"
            }
        }

        struct Context: Equatable {
            let creature: StatBlock
            let action: CreatureAction
            var diceAction: DiceAction? = nil
        }

        // configurable in this view
        struct Settings: Equatable {
            var outcome: OutcomeSetting?
            var impact: CreatureActionDescriptionRequest.Impact

            enum OutcomeSetting: Hashable {
                case hit
                case miss
            }
        }
    }

    public struct RequestInput: Reducer {
        public struct State: Hashable {
            var request: CreatureActionDescriptionRequest? = nil
        }

        public enum Action: Equatable, BindableAction {
            case binding(BindingAction<State>)
        }

        public var body: some ReducerOf<Self> {
            BindingReducer()
        }
    }

    public enum Action: Equatable, BindableAction {
        case onAppear
        case onFeedbackButtonTap
        case onReloadOrCancelButtonTap
        case didRollDiceAction(DiceAction)
        case onDisappear

        case description(State.AsyncDescription.Action)
        case binding(BindingAction<State>)
    }

    public var body: some ReducerOf<Self> {
        CombineReducers {
            Reduce { state, action in
                switch action {
                case .onAppear:
                    state.mechMuseIsConfigured = environment.mechMuse.isConfigured
                case .onFeedbackButtonTap: break // handled by the parent
                case .onReloadOrCancelButtonTap:
                    if state.description.result.isReducing {
                        return .send(.description(.result(.stop)))
                    } else {
                        return .send(.description(.set(state.input, nil)))
                    }
                case .didRollDiceAction(let action):
                    state.context.diceAction = action
                    if action.isCriticalHit {
                        state.settings.outcome = .hit
                    } else if action.isCriticalMiss {
                        state.settings.outcome = .miss
                    }
                case .onDisappear:
                    return .run { send in await send(.description(.result(.stop))) }
                case .description: break // handled by child reducer
                case .binding: break // handled by wrapper reducer
                }
                return .none
            }

            BindingReducer()
                .onChange(of: \.context) { oldValue, newValue in
                    Reduce { state, action in
                        state.cache.removeAll()
                        return .none
                    }
                }
        }.onChange(of: \.input) { oldValue, newValue in
            Reduce { state, action in
                guard newValue.request != nil else { return .none }
                if let cacheHit = state.cache[newValue] {
                    return .send(.description(.set(newValue, cacheHit)))
                } else {
                    return .send(.description(.set(newValue, nil)))
                }
            }
        }

        Scope(state: \.description, action: /Action.description) {
            State._AsyncDescription_Map(
                inputReducer: RequestInput(),
                initialResultStateForInput: { _ in State._AsyncDescription_Reduce.State(value: "") },
                initialResultActionForInput: { _ in State._AsyncDescription_Reduce.Action.start("") },
                resultReducerForInput: { input in
                    State._AsyncDescription_Reduce {
                        guard let request = input.request else { throw ActionDescriptionFeatureError.missingInput }
                        return try environment.mechMuse.describe(action: request)
                    } reduce: { result, element in
                        result += element
                    } mapError: {
                        ($0 as? MechMuseError) ?? .unspecified
                    }

                }
            ).retaining { $0.result }
        }
        .onChange(of: \.description.result) { _, newValue in
            Reduce { state, action in
                if state.description.input.request != nil && newValue.isFinished {
                    state.cache[state.input] = newValue
                }
                return .none
            }
        }

    }
}

public typealias ActionDescriptionEnvironment = EnvironmentWithMainQueue & EnvironmentWithMechMuse


extension ActionDescriptionFeature.State {
    fileprivate var input: ActionDescriptionFeature.RequestInput.State {
        return effectiveOutcome.map { outcome in
            ActionDescriptionFeature.RequestInput.State(
                request: CreatureActionDescriptionRequest(
                    creatureName: encounterContext?.combatant.name ?? context.creature.name,
                    isUniqueCreature: false, // todo
                    creatureDescription: encounterContext?.creatureTraits ?? CreatureActionDescriptionRequest.creatureDescription(from: context.creature),
                    creatureCondition: nil,
                    encounter: (encounterContext?.encounter).map {
                        .init(name: $0.name, actionSetUp: nil)
                    },
                    actionName: context.action.name,
                    actionDescription: context.action.description,
                    outcome: outcome
                )
            )
        } ?? .init()
    }
}

enum ActionDescriptionFeatureError: Swift.Error {
    case missingInput
}

extension ActionResolutionFeature.State.EncounterContext {
    var creatureTraits: String? {
        guard let c = combatant.traits else { return nil }

        switch (c.physical, c.personality) {
        case let (a?, b?): return "\(a), \(b)"
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }
}

extension DiceAction {
    var isCriticalHit: Bool {
        steps.first { step in
            step.rollValue?.isToHit == true
        }?.rollValue?.result?.dice.first(where: { die in
            die.die == .d20
        })?.value == 20
    }

    var isCriticalMiss: Bool {
        steps.first { step in
            step.rollValue?.isToHit == true
        }?.rollValue?.result?.dice.first(where: { die in
            die.die == .d20
        })?.value == 1
    }

    var effects: [(Int, DamageType)] {
        steps.compactMap { step in
            guard case .damage(let damage) = step.rollValue?.roll else { return nil }
            guard case let roll? = step.rollValue?.result else { return nil }
            return (roll.total, damage.type)
        }
    }

    var damageDescription: String {
        let damageListFormatter = ListFormatter()
        damageListFormatter.locale = Locale(identifier: "en_US")

        let damageList = effects.map { "\($0.0) \($0.1.rawValue) damage" }
        return damageListFormatter.string(from: damageList) ?? CreatureActionDescriptionRequest.Outcome.averageHitDamageDescription
    }
}
