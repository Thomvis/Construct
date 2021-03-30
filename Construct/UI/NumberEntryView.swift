//
//  NumberEntryView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

// A view that allows entry of a number, either directly or through a simulated dice roll
struct NumberEntryView: View {
    var store: Store<NumberEntryViewState, NumberEntryViewAction>
    @ObservedObject var viewStore: ViewStore<NumberEntryViewState, NumberEntryViewAction>

    init(store: Store<NumberEntryViewState, NumberEntryViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var body: some View {
        VStack {
            Picker("Type", selection: viewStore.binding(get: { $0.mode }, send: { .mode($0) })) {
                Text("Roll").tag(NumberEntryViewState.Mode.dice)
                Text("Manual").tag(NumberEntryViewState.Mode.pad)
            }.pickerStyle(SegmentedPickerStyle())

            if viewStore.state.mode == .dice {
                DiceCalculatorView(store: store.scope(state: { $0.diceState }, action: { .dice($0) }))
            } else if viewStore.state.mode == .pad {
                NumberPadView(store: store.scope(state: { $0.padState }, action: { .pad($0) }))
            }
        }
    }
}

struct NumberEntryViewState: Hashable {
    var mode: Mode
    var padState: NumberPadViewState
    var diceState: DiceCalculatorState

    var value: Int? {
        switch mode {
        case .pad: return padState.value
        case .dice: return diceState.result(includingIntermediary: false)?.total
        }
    }

    enum Mode: Hashable {
        case pad
        case dice
    }
}

enum NumberEntryViewAction: Equatable {
    case mode(NumberEntryViewState.Mode)
    case pad(NumberPadViewAction)
    case dice(DiceCalculatorAction)
}

extension NumberEntryViewState {
    static func pad(value: Int, expression: DiceExpression? = nil) -> NumberEntryViewState {
        return NumberEntryViewState(mode: .pad, padState: NumberPadViewState(value: value), diceState: expression.map { .rollingExpression($0) } ?? .editingExpression())
    }

    static func dice(_ state: DiceCalculatorState) -> NumberEntryViewState {
        return NumberEntryViewState(mode: .dice, padState: NumberPadViewState(value: 0), diceState: state)
    }

    static func initiative(combatant: Combatant) -> NumberEntryViewState {
        if combatant.definition.player != nil {
            return NumberEntryViewState.pad(
                value: combatant.initiative ?? 0,
                expression: combatant.definition.initiativeModifier.map { 1.d(20) + $0 }
            )
        } else if let mod = combatant.definition.initiativeModifier {
            return NumberEntryViewState.dice(.rollingExpression(1.d(20) + mod, prefilledResult: combatant.initiative))
        } else if let initiative = combatant.initiative {
            return NumberEntryViewState.dice(.rollingExpression(1.d(20), prefilledResult: initiative))
        } else {
            return NumberEntryViewState.dice(.editingExpression(1.d(20)))
        }
    }

    static var reducer: Reducer<Self, NumberEntryViewAction, Environment> = Reducer.combine(
        Reducer { state, action, _ in
            switch action {
            case .mode(let m):
                state.mode = m
            case .pad, .dice: break // handled by reducers below
            }
            return .none
        },
        NumberPadViewState.reducer.pullback(state: \.padState, action: /NumberEntryViewAction.pad, environment: { $0 }),
        DiceCalculatorState.reducer.pullback(state: \.diceState, action: /NumberEntryViewAction.dice, environment: { $0 })
    )
}

extension NumberEntryViewState {
    static let nullInstance = NumberEntryViewState(mode: .dice, padState: NumberPadViewState(value: 0), diceState: DiceCalculatorState(displayOutcomeExternally: false, rollOnAppear: false, expression: .number(0), mode: .editingExpression))
}
