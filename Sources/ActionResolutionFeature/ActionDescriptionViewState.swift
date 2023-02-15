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
    public typealias AsyncDescriptionReduceState = AsyncReduceState<String, MechMuseError>
    public typealias AsyncDescriptionMapState = MapState<RequestInput?, AsyncDescriptionReduceState>
    public typealias AsyncDescription = RetainState<AsyncDescriptionMapState, AsyncDescriptionReduceState>

    let encounterContext: ActionResolutionViewState.EncounterContext?
    @BindableState var context: Context
    @BindableState var settings: Settings = .init(toneOfVoice: .gritty, outcome: nil, impact: .average)

    private var description: AsyncDescription = .init(wrapped: .init(input: nil, result: .init(value: "")))
    private var cache: [RequestInput: AsyncReduceState<String, MechMuseError>] = [:]

    init(
        encounterContext: ActionResolutionViewState.EncounterContext? = nil,
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
        guard let error = description.wrapped.result.error else { return nil }
        switch error {
        case MechMuseError.unconfigured: return try? AttributedString(markdown: "Mechanical Muse can provide you with a description of this attack to inspire your DM'ing. Configure Mechanical Muse in the settings screen.")
        default: return error.attributedDescription
        }
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
        var toneOfVoice: ToneOfVoice
        var outcome: OutcomeSetting?
        var impact: CreatureActionDescriptionRequest.Impact

        enum OutcomeSetting: Hashable {
            case hit
            case miss
        }
    }

    public struct RequestInput: Hashable {
        var request: CreatureActionDescriptionRequest
        var toneOfVoice: ToneOfVoice
    }
}

public enum ActionDescriptionViewAction: Equatable, BindableAction {
    case onAppear
    case onFeedbackButtonTap
    case onReloadOrCancelButtonTap
    case didRollDiceAction(DiceAction)
    case onDisappear

    case description(MapAction<ActionDescriptionViewState.RequestInput?, ActionDescriptionViewInputAction, AsyncReduceState<String, MechMuseError>, AsyncReduceAction<String, MechMuseError, String>>)
    case binding(BindingAction<ActionDescriptionViewState>)
}

public typealias ActionDescriptionEnvironment = EnvironmentWithMainQueue & EnvironmentWithMechMuse

public enum ActionDescriptionViewInputAction: Equatable, BindableAction {
    case binding(BindingAction<ActionDescriptionViewState.RequestInput>)
}

extension ActionDescriptionViewState.RequestInput {
    static var reducer: AnyReducer<Self, ActionDescriptionViewInputAction, ActionDescriptionEnvironment> = AnyReducer.combine().binding()
}

extension ActionDescriptionViewState {
    static var reducer: AnyReducer<Self, ActionDescriptionViewAction, ActionDescriptionEnvironment> = AnyReducer.combine(
        AnyReducer { state, action, env in
            switch action {
            case .onAppear: break
            case .onFeedbackButtonTap: break // handled by the parent
            case .onReloadOrCancelButtonTap:
                if state.description.result.isReducing {
                    return Effect(value: .description(.result(.stop)))
                } else {
                    return Effect(value: .description(.set(state.input, nil)))
                }
            case .didRollDiceAction(let a):
                state.context.diceAction = a
                if a.isCriticalHit {
                    // 20 always hits
                    state.settings.outcome = .hit
                } else if a.isCriticalMiss {
                    // 1 always misses
                    state.settings.outcome = .miss
                }
            case .onDisappear:
                return .task { return .description(.result(.stop)) }
            case .description: break // handled by child reducer
            case .binding: break // handled by wrapper reducer
            }
            return .none
        },
        AsyncDescriptionMapState.reducer(
            inputReducer: ActionDescriptionViewState.RequestInput.reducer.binding().optional(),
            initialResultStateForInput: { _ in AsyncReduceState(value: "") },
            initialResultActionForInput: { _ in .start("") },
            resultReducerForInput: { input in
                AsyncDescriptionReduceState.reducer({ env in
                    guard let input else { throw ActionDescriptionViewStateError.missingInput }
                    return try env.mechMuse.describe(
                        action: input.request,
                        toneOfVoice: input.toneOfVoice
                    )
                }, reduce: { res, elem in
                    // append tokens as they come in
                    res += elem
                }, mapError: {
                    ($0 as? MechMuseError) ?? MechMuseError.unspecified
                })
            }
        )
        .retaining {
            $0.result
        }
        .pullback(state: \.description, action: /ActionDescriptionViewAction.description)
    )
    .binding()
    // clear cache if the context changes, because any change in settings won't ever result in a cache hit
    .onChange(of: \.context, perform: { _, state, _, _ in
        state.cache.removeAll()
        return .none
    })
    .onChange(of: \.input, perform: { input, state, action, env in
        guard let input else { return .none }
        if let cacheHit = state.cache[input] {
            // cache hit
            return EffectTask(value: .description(.set(input, cacheHit)))
        } else {
            // trigger fetch
            return .task { .description(.set(input, nil)) }
        }
    })
    // add results to the cache
    .onChange(of: \.description.result, perform: { v, state, _, _ in
        if let input = state.description.input, v.isFinished {
            state.cache[input] = v
        }
        return .none
    })
}

extension ActionDescriptionViewState {
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
                ),
                toneOfVoice: settings.toneOfVoice
            )
        }
    }
}

enum ActionDescriptionViewStateError: Swift.Error {
    case missingInput
}

extension ActionResolutionViewState.EncounterContext {
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
