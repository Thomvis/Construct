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

    let encounterContext: ActionResolutionViewState.EncounterContext?
    @BindableState var context: Context
    @BindableState var settings: Settings = .init(toneOfVoice: .gritty, outcome: nil, impact: .average)

    private var description: AsyncDescription = .init(input: nil)
    private var cache: [RequestInput: String] = [:]

    init(
        encounterContext: ActionResolutionViewState.EncounterContext? = nil,
        creature: StatBlock,
        action: CreatureAction
    ) {
        self.encounterContext = encounterContext
        self.context = Context(creature: creature, action: action)
    }

    var descriptionString: String? {
        description.value
    }

    var descriptionErrorString: AttributedString? {
        guard let error = description.error else { return nil }
        switch error {
        case MechMuseError.unconfigured: return try? AttributedString(markdown: "Mechanical Muse can provide you with a description of this attack to inspire your DM'ing. Configure Mechanical Muse in the settings screen.")
        case MechMuseError.insufficientQuota: return try? AttributedString(markdown: "You have exceeded your OpenAI usage limits. Please update your OpenAI [account settings](https://beta.openai.com/account/billing/limits).")
        case MechMuseError.invalidAPIKey: return AttributedString("Invalid OpenAI API Key. Please check the Mechanical Muse configuration in the settings screen.")
        default: return AttributedString("Could not generate description due to an unforseen error.")
        }
    }

    var isLoadingDescription: Bool {
        description.result.isLoading
    }

    var didFailLoading: Bool {
        description.error != nil
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
            case .onFeedbackButtonTap: break // handled by the parent
            case .didRollDiceAction(let a):
                state.context.diceAction = a
                if a.isCriticalHit {
                    // 20 always hits
                    state.settings.outcome = .hit
                } else if a.isCriticalMiss {
                    // 1 always misses
                    state.settings.outcome = .miss
                }
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
    // clear cache if the context changes, because any change in settings won't ever result in a cache hit
    .onChange(of: \.context, perform: { _, state, _, _ in
        state.cache.removeAll()
        return .none
    })
    .onChange(of: \.input, perform: { input, state, action, env in
        if let input, let cacheHit = state.cache[input] {
            // cache hit
            state.description.setValue(cacheHit, for: input)
            return .none
        } else {
            // trigger fetch
            return .task { .description(.setInput(input, debounce: false)) }
        }
    })
    // add results to the cache
    .onChange(of: \.description.result.value, perform: { v, state, _, _ in
        if let value = v, let input = state.description.input {
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
                    creatureDescription: encounterContext?.creatureDescription ?? CreatureActionDescriptionRequest.creatureDescription(from: context.creature),
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
    var creatureDescription: String? {
        guard let c = combatant.characteristics else { return nil }

        switch (c.appearance, c.behavior) {
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
