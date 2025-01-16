//
//  CombatantFeature.swift
//  Construct
//
//  Created by Thomas Visser on 02/10/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import ComposableArchitecture
import Combine

enum CombatantAction: Equatable {
    case hp(Hp.Action)
    case initiative(Int)
    case resource(CombatantResource.Id, CombatantResourceAction)
    case addResource(CombatantResource)
    case removeResource(CombatantResource)
    case addTag(CombatantTag)
    case removeTag(CombatantTag)
    case reset(hp: Bool, initiative: Bool, resources: Bool, tags: Bool)
    case setDefinition(Combatant.CodableCombatDefinition)
    case removeTraits

    var hp: Hp.Action? {
        get {
            guard case .hp(let a) = self else { return nil }
            return a
        }
        set {
            guard case .hp = self, let value = newValue else { return }
            self = .hp(value)
        }
    }
}

let combatantReducer: AnyReducer<Combatant, CombatantAction, Void> = AnyReducer.combine(
    AnyReducer { state, action, _ in
    switch action {
    case .initiative(let score): state.initiative = score
    case .addResource(let r): state.resources.append(r)
    case .removeResource(let r): state.resources.removeAll { $0.id == r.id }
    case .addTag(let t): state.tags[id: t.id] = t
    case .removeTag(let t): state.tags.removeAll { $0.id == t.id }
    case .hp, .resource: break
    case .reset(let hp, let initiative, let resources, let tags):
        if initiative { state.initiative = nil }
        if tags { state.tags.removeAll() }

        return .run { [state] send in
            if resources {
                for r in state.resources {
                    send(CombatantAction.resource(r.id, .reset))
                }
            }

            if hp {
                send(.hp(.reset))
            }
        }
    case .setDefinition(let def):
        if state.definition.definitionID != def.definition.definitionID {
            state.discriminator = nil
        }
        state.definition = def.definition
    case .removeTraits:
        state.traits = nil
    }
    return .none
},
Hp.reducer.optional().pullback(state: \.hp, action: /CombatantAction.hp, environment: { $0 }),
CombatantResource.reducer.forEach(state: \.resources, action: /CombatantAction.resource, environment: { $0 })
)

enum CombatantResourceAction: Equatable {
    case title(String)
    case reset
    case slot(Int, Bool)
}

extension Hp {
    enum Action: Equatable {
        case current(ModifyIntAction)
        case maximum(ModifyIntAction)
        case temporary(ModifyIntAction)
        case reset
    }

    enum ModifyIntAction: Equatable {
        case add(Int)
        case set(Int)
    }

    static let reducer: AnyReducer<Hp, Action, Void> = AnyReducer { state, action, _ in
        switch action {
        case .current(let m):
            switch m {
            case .add(let p): state.apply(p)
            case .set(let p): state.current = p
            }
        case .maximum(let m):
            switch m {
            case .add(let p):
                state.maximum += p
                state.apply(0)
            case .set(let p):
                state.maximum = p
                state.apply(0)
            }
        case .temporary(let m):
            switch m {
            case .add(let p): state.temporary += p
            case .set(let p): state.temporary = p
            }
        case .reset:
            state.current = state.maximum
            state.temporary = 0
        }
        return .none
    }
}

extension CombatantResource {
    static let reducer: AnyReducer<CombatantResource, CombatantResourceAction, Void> = AnyReducer { state, action, _ in
        switch action {
        case .title(let t):
            state.title = t
        case .reset:
            state.reset()
        case .slot(let idx, let v):
            state.slots[idx] = v
        }
        return .none
    }
}
