//
//  NumberEntryPopover.swift
//  Construct
//
//  Created by Thomas Visser on 27/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

// A popover that allows for number entry, either by hand or by simulated dice rolls
struct NumberEntryPopover: Popover, View {

    var popoverId: AnyHashable { "NumberEntryPopover" }
    var store: Store<NumberEntryViewState, NumberEntryViewAction>
    let onOutcomeSelected: (Int) -> Void

    init(store: Store<NumberEntryViewState, NumberEntryViewAction>, onOutcomeSelected: @escaping (Int) -> Void) {
        self.store = store
        self.onOutcomeSelected = onOutcomeSelected
    }

    init(environment: Environment, initialState: NumberEntryViewState, onOutcomeSelected: @escaping (Int) -> Void) {
        self.store = Store(initialState: initialState, reducer: NumberEntryViewState.reducer, environment: environment)
        self.onOutcomeSelected = onOutcomeSelected
    }

    init(environment: Environment, rollExpression ex: DiceExpression = .number(0), prefilledResult: Int? = nil, onOutcomeSelected: @escaping (Int) -> Void) {
        self.init(environment: environment, initialState: .dice(.rollingExpression(ex, rollOnAppear: true, prefilledResult: prefilledResult)), onOutcomeSelected: onOutcomeSelected)
    }

    init(environment: Environment, rollD20WithModifier mod: Int, prefilledResult: Int? = nil, onOutcomeSelected: @escaping (Int) -> Void) {
        self.init(environment: environment, rollExpression: 1.d(20) + mod, prefilledResult: prefilledResult, onOutcomeSelected: onOutcomeSelected)
    }

    static func editExpression(environment: Environment, expression: DiceExpression = .number(0), onOutcomeSelected: @escaping (Int) -> Void) -> Self {
        Self(environment: environment, initialState: .dice(.editingExpression(expression)), onOutcomeSelected: onOutcomeSelected)
    }

    static func manualEntry(environment: Environment, onOutcomeSelected: @escaping (Int) -> Void) -> Self {
        Self(environment: environment, initialState: .pad(value: 0), onOutcomeSelected: onOutcomeSelected)
    }

    static func initiative(environment: Environment, combatant: Combatant, onOutcomeSelected: @escaping (Int) -> Void) -> Self {
        let state: NumberEntryViewState
        if combatant.definition.player != nil {
            state = NumberEntryViewState.pad(
                value: combatant.initiative ?? 0,
                expression: combatant.definition.initiativeModifier.map { 1.d(20) + $0 }
            )
        } else if let mod = combatant.definition.initiativeModifier {
            state = NumberEntryViewState.dice(.rollingExpression(1.d(20) + mod, prefilledResult: combatant.initiative))
        } else if let initiative = combatant.initiative {
            state = NumberEntryViewState.dice(.rollingExpression(1.d(20), prefilledResult: initiative))
        } else {
            state = NumberEntryViewState.dice(.editingExpression(1.d(20)))
        }
        return Self(environment: environment, initialState: state, onOutcomeSelected: onOutcomeSelected)
    }

    var body: some View {
        WithViewStore(store.scope(state: State.init)) { viewStore in
            VStack {
                NumberEntryView(store: self.store)
                Divider()
                Button(action: {
                    self.onOutcomeSelected(viewStore.state.outcome ?? 0)
                }) {
                    Text("Use")
                }.disabled(viewStore.state.outcome == nil)
            }
        }
    }

    func makeBody() -> AnyView {
        return AnyView(self)
    }

    struct State: Equatable {
        let outcome: Int?

        init(_ state: NumberEntryViewState) {
            self.outcome = state.value
        }
    }
}
