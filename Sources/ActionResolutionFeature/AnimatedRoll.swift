import Foundation
import SwiftUI
import ComposableArchitecture
import Dice

@Reducer
public struct AnimatedRoll {
    @ObservableState
    public struct State: Hashable {
        var expression: DiceExpression?
        var result: RolledDiceExpression?

        var intermediaryResult: RolledDiceExpression?

        var effectiveResult: RolledDiceExpression? {
            intermediaryResult ?? result
        }

        var isFinal: Bool {
            result != nil && intermediaryResult == nil
        }
    }

    public enum Action: Hashable {
        case roll(DiceExpression)
        case rollIntermediary(DiceExpression, Int)
    }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .roll(let expr):
            state.expression = expr
            state.result = expr.roll
            return .send(.rollIntermediary(expr, 5))
        case .rollIntermediary(let expr, let remaining):
            guard expr == state.expression && remaining > 0 else {
                state.intermediaryResult = nil
                return .none
            }

            state.intermediaryResult = expr.roll

            return Effect.run { send in
                try await Task.sleep(for: .seconds(0.08))
                await send(.rollIntermediary(expr, remaining-1), animation: .default)
            }
        }
    }
}

struct AnimatedRollView<Content>: View where Content: View {
    @Binding var roll: AnimatedRoll.State
    let content: (RolledDiceExpression?, Bool) -> Content

    var body: some View {
        content(roll.effectiveResult, roll.isFinal)
    }
}
