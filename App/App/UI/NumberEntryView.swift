import Foundation
import SwiftUI
import ComposableArchitecture
import DiceRollerFeature
import Dice
import GameModels
import Helpers

public struct NumberEntryFeature: Reducer {
    public struct State: Equatable {
        var mode: Mode
        var pad: NumberPadFeature.State
        var dice: DiceCalculator.State

        public init(
            mode: Mode = .dice,
            pad: NumberPadFeature.State = NumberPadFeature.State(value: 0),
            dice: DiceCalculator.State = .editingExpression()
        ) {
            self.mode = mode
            self.pad = pad
            self.dice = dice
        }

        var value: Int? {
            switch mode {
            case .pad:
                return pad.value
            case .dice:
                return dice.result(includingIntermediary: false)?.total
            }
        }

        public enum Mode: Hashable {
            case pad
            case dice
        }
    }

    public enum Action: Equatable {
        case mode(State.Mode)
        case pad(NumberPadFeature.Action)
        case dice(DiceCalculator.Action)
    }

    typealias Environment = NumberEntryViewEnvironment

    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \State.pad, action: /Action.pad) {
            NumberPadFeature()
        }

        Scope(state: \State.dice, action: /Action.dice) {
            DiceCalculator(environment: environment)
        }

        Reduce { state, action in
            switch action {
            case .mode(let mode):
                state.mode = mode
            case .pad, .dice:
                break
            }
            return .none
        }
    }
}

typealias NumberEntryViewEnvironment = EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog

public extension NumberEntryFeature.State {
    static func pad(value: Int, expression: DiceExpression? = nil) -> Self {
        Self(
            mode: .pad,
            pad: NumberPadFeature.State(value: value),
            dice: expression.map { .rollingExpression($0) } ?? .editingExpression()
        )
    }

    static func dice(_ state: DiceCalculator.State) -> Self {
        Self(
            mode: .dice,
            pad: NumberPadFeature.State(value: 0),
            dice: state
        )
    }

    static func initiative(combatant: Combatant) -> Self {
        if combatant.definition.player != nil {
            return .pad(
                value: combatant.initiative ?? 0,
                expression: combatant.definition.initiativeModifier.map { 1.d(20) + $0 }
            )
        } else if let mod = combatant.definition.initiativeModifier {
            return .dice(.rollingExpression(1.d(20) + mod, prefilledResult: combatant.initiative))
        } else if let initiative = combatant.initiative {
            return .dice(.rollingExpression(1.d(20), prefilledResult: initiative))
        } else {
            return .dice(.editingExpression(1.d(20)))
        }
    }

    static let nullInstance = Self(
        mode: .dice,
        pad: NumberPadFeature.State(value: 0),
        dice: DiceCalculator.State(displayOutcomeExternally: false, rollOnAppear: false, expression: .number(0), mode: .editingExpression)
    )
}

struct NumberEntryView: View {
    let store: StoreOf<NumberEntryFeature>

    init(store: StoreOf<NumberEntryFeature>) {
        self.store = store
    }

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack {
                Picker(
                    "Type",
                    selection: viewStore.binding(
                        get: \.mode,
                        send: NumberEntryFeature.Action.mode
                    ).animation(.spring())
                ) {
                    Text("Roll").tag(NumberEntryFeature.State.Mode.dice)
                    Text("Manual").tag(NumberEntryFeature.State.Mode.pad)
                }
                .pickerStyle(.segmented)

                if viewStore.state.mode == .dice {
                    DiceCalculatorView(store: store.scope(state: \.dice, action: NumberEntryFeature.Action.dice))
                } else {
                    NumberPadView(store: store.scope(state: \.pad, action: NumberEntryFeature.Action.pad))
                }
            }
        }
    }
}
