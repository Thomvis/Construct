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
        public typealias AsyncDescriptionReduceState = AsyncReduceState<String, MechMuseError>
        public typealias AsyncDescriptionMapState = MapState<RequestInput?, AsyncDescriptionReduceState>
        public typealias AsyncDescription = RetainState<AsyncDescriptionMapState, AsyncDescriptionReduceState>

        let encounterContext: ActionResolutionFeature.State.EncounterContext?
        @BindingState var context: Context
        @BindingState var settings: Settings = .init(outcome: nil, impact: .average)

        fileprivate var description: AsyncDescription = .init(wrapped: .init(input: nil, result: .init(value: "")))
        fileprivate var cache: [RequestInput: AsyncReduceState<String, MechMuseError>] = [:]
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

        public struct RequestInput: Hashable {
            var request: CreatureActionDescriptionRequest
        }
    }

    public enum Action: Equatable, BindableAction {
        case onAppear
        case onFeedbackButtonTap
        case onReloadOrCancelButtonTap
        case didRollDiceAction(DiceAction)
        case onDisappear

        case description(MapAction<State.RequestInput?, RequestInputAction, State.AsyncDescriptionReduceState, AsyncReduceAction<String, MechMuseError, String>>)
        case binding(BindingAction<State>)
    }

    public enum RequestInputAction: Equatable, BindableAction {
        case binding(BindingAction<State.RequestInput>)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            let descriptionEffect = Self.descriptionReducer.reduce(into: &state, action: action, environment: environment)

            switch action {
            case .onAppear:
                state.mechMuseIsConfigured = environment.mechMuse.isConfigured
                return descriptionEffect

            case .onFeedbackButtonTap:
                return descriptionEffect

            case .onReloadOrCancelButtonTap:
                let effect: Effect<Action>
                if state.description.result.isReducing {
                    effect = .send(.description(.result(.stop)))
                } else {
                    effect = .send(.description(.set(state.input, nil)))
                }
                return .merge(descriptionEffect, effect)

            case .didRollDiceAction(let diceAction):
                state.context.diceAction = diceAction
                if diceAction.isCriticalHit {
                    state.settings.outcome = .hit
                } else if diceAction.isCriticalMiss {
                    state.settings.outcome = .miss
                }
                return descriptionEffect

            case .onDisappear:
                return .merge(descriptionEffect, .task { .description(.result(.stop)) })

            case .description:
                return descriptionEffect

            case .binding:
                return descriptionEffect
            }
        }

        BindingReducer()
            .onChange(of: \.context) { _, state, _, _ in
                state.cache.removeAll()
                return .none
            }
            .onChange(of: \.input) { input, state, _, _ in
                guard let input else { return .none }
                if let cacheHit = state.cache[input] {
                    return EffectTask(value: .description(.set(input, cacheHit)))
                } else {
                    return .task { .description(.set(input, nil)) }
                }
            }
            .onChange(of: \.description.result) { result, state, _, _ in
                if let input = state.description.input, result.isFinished {
                    state.cache[input] = result
                }
                return .none
            }
    }
}

public typealias ActionDescriptionEnvironment = EnvironmentWithMainQueue & EnvironmentWithMechMuse

extension ActionDescriptionFeature.State.RequestInput {
    static var reducer: AnyReducer<Self, ActionDescriptionFeature.RequestInputAction, ActionDescriptionEnvironment> = AnyReducer.combine().binding()
}

extension ActionDescriptionFeature {
    private static let descriptionReducer: AnyReducer<State, Action, ActionDescriptionEnvironment> = AsyncDescriptionMapState.reducer(
        inputReducer: State.RequestInput.reducer.binding().optional(),
        initialResultStateForInput: { _ in State.AsyncDescriptionReduceState(value: "") },
        initialResultActionForInput: { _ in .start("") },
        resultReducerForInput: { input in
            State.AsyncDescriptionReduceState.reducer({ env in
                guard let input else { throw ActionDescriptionFeatureError.missingInput }
                return try env.mechMuse.describe(
                    action: input.request
                )
            }, reduce: { result, element in
                result += element
            }, mapError: {
                ($0 as? MechMuseError) ?? MechMuseError.unspecified
            })
        }
    )
    .retaining {
        $0.result
    }
    .pullback(state: \.description, action: /Action.description, environment: { $0 })
}

extension ActionDescriptionFeature.State {
    fileprivate var input: RequestInput? {
        return effectiveOutcome.map { outcome in
            RequestInput(
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
        }
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
