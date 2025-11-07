import Foundation
import ComposableArchitecture
import DiceRollerFeature

struct FloatingDiceRollerFeature: Reducer {
    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    struct State: Equatable {
        var hidden: Bool = false
        var content: Content = .calculator
        var diceCalculator: DiceCalculator.State
        var diceLog = DiceLog()

        var canCollapse: Bool {
            diceCalculator.mode != .rollingExpression
        }

        enum Content: Equatable {
            case calculator
            case log
        }
    }

    enum Action: Equatable {
        case diceCalculator(DiceCalculator.Action)
        case hide
        case content(State.Content)
        case show
        case collapse
        case expand

        case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
        case onClearDiceLog
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.diceCalculator, action: /Action.diceCalculator) {
            DiceCalculator(environment: environment)
        }
        Reduce { state, action in
            switch action {
            case .diceCalculator: break // handled above
            case .hide:
                state.hidden = true
            case .content(let c):
                state.content = c
            case .show:
                state.hidden = false
                state.diceCalculator.mode = .editingExpression
            case .collapse:
                state.diceCalculator.mode = .rollingExpression
            case .expand:
                state.diceCalculator.mode = .editingExpression
            case .onProcessRollForDiceLog(let result, let roll):
                state.diceLog.receive(result, for: roll)
            case .onClearDiceLog:
                state.diceLog.clear()
            }
            return .none
        }
    }
}

