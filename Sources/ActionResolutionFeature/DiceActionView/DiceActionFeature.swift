import Foundation
import ComposableArchitecture
import ComposableArchitecture
import DiceRollerFeature

public struct DiceActionFeature: Reducer {

    public struct State: Hashable {
        var creatureName: String
        var action: DiceAction

        // to keep track of which steps are being rolled
        var rollingSteps: [UUID] = []
    }

    public enum Action: Hashable {
        case rollAll
        case onFeedbackButtonTap
        case stepAction(DiceAction.Step.ID, DiceActionFeature.StepAction)
    }

    public enum StepAction: Hashable {
        case value(ValueAction)
        case rollDetails(DiceCalculator.Action)

        public enum ValueAction: Hashable {
            case roll(RollAction)

            public enum RollAction: Hashable {
                case roll
                case type(DiceAction.Step.Value.RollValue.RollType)
                case first(AnimatedRoll.Action)
                case second(AnimatedRoll.Action)
                case details(DiceAction.Step.Value.RollValue.Details?)
            }
        }
    }

    @Dependency(\.diceLog) var diceLog

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rollAll:
                return .merge(
                    state.action.steps.compactMap { step -> Effect<Action>? in
                        guard case .roll = step.value else { return nil }
                        return .send(.stepAction(step.id, .value(.roll(.roll))))
                    }
                )
            case .onFeedbackButtonTap: break // handled by the parent
            case .stepAction(let id, .value(.roll(.details(_?)))):
                return .merge(
                    state.action.steps
                        .filter { $0.id != id && $0.rollDetails != nil }
                        .map { step in
                            .send(.stepAction(step.id, .value(.roll(.details(nil)))))
                        }
                )
            case .stepAction(let id, .value(.roll(.first(.roll)))),
                    .stepAction(let id, .value(.roll(.second(.roll)))):
                state.rollingSteps.append(id)
            case .stepAction(let id, .rollDetails(DiceCalculator.Action.onResultDieTap)):
                state.rollingSteps.append(id)
                fallthrough
            case .stepAction(_, .value(.roll(.first(.rollIntermediary(_, 0))))),
                    .stepAction(_, .value(.roll(.second(AnimatedRoll.Action.rollIntermediary(_, 0))))),
                    .stepAction(_, .rollDetails(.intermediaryResultsStep(_, 0))):

                // check if all rolling steps have finished
                for id in state.rollingSteps {
                    guard let step = state.action.steps[id: id] else { return .none }
                    guard case .roll(let roll) = step.value else { return .none }
                    guard roll.first.intermediaryResult == nil && roll.second?.intermediaryResult == nil else { return .none }
                }

                // report rolls to the dice log
                for step in state.action.steps where state.rollingSteps.contains(step.id) {
                    guard case .roll(let roll) = step.value else { continue }
                    guard let firstResult = roll.first.result else { continue }

                    let description = RollDescription.diceActionStep(
                        creatureName: state.creatureName,
                        actionTitle: state.action.title,
                        stepTitle: step.title,
                        expression: firstResult.unroll
                    )

                    if roll.type == .normal {
                        diceLog.didRoll(
                            firstResult,
                            roll: description
                        )
                    } else if let second = roll.second {
                        guard let secondResult = second.result else { break }
                        diceLog.didRoll(
                            DiceLogEntry.Result(
                                type: roll.type == .advantage ? .advantage : .disadvantage, // todo: unify enums
                                first: firstResult,
                                second: secondResult
                            ),
                            roll: description
                        )
                    }
                }

                state.rollingSteps.removeAll()
            case .stepAction: break
            }
            return .none
        }.forEach(\.action.steps, action: /Action.stepAction) {
            stepReducer
        }
    }

    @ReducerBuilder<DiceAction.Step, DiceActionFeature.StepAction>
    private var stepReducer: some Reducer<DiceAction.Step, DiceActionFeature.StepAction> {
        Reduce { state, action in
            switch action {
            case .value(.roll(.roll)):
                guard let rollValue = state.rollValue else { return .none }

                var effects: [Effect<DiceActionFeature.StepAction>] = [
                    .send(.value(.roll(.first(.roll(rollValue.expression)))))
                ]

                if rollValue.type != .normal {
                    effects.append(.send(.value(.roll(.second(.roll(rollValue.expression))))))
                }

                return .merge(effects)
            case .value(.roll(.type(let t))):
                guard let rollValue = state.rollValue else { return .none }

                state.rollValue?.type = t
                if t != .normal {
                    if state.rollValue?.second == nil {
                        state.rollValue?.second = AnimatedRoll.State(expression: rollValue.expression, result: nil, intermediaryResult: nil)
                        if rollValue.first.result != nil {
                            return .send(.value(.roll(.second(.roll(rollValue.expression)))))
                        }
                    }
                } else {
                    state.rollValue?.second = nil
                }
            case .value(.roll(.details(let d))):
                state.rollValue?.details = d
            case .value(.roll): break
            case .rollDetails: break // handled above
            }
            return .none
        }.ifLet(\.rollValue, action: /DiceActionFeature.StepAction.value..DiceActionFeature.StepAction.ValueAction.roll) {
            Scope(
                state: \.first,
                action: /DiceActionFeature.StepAction.ValueAction.RollAction.first
            ) {
                AnimatedRoll()
            }.ifLet(\.second, action: /DiceActionFeature.StepAction.ValueAction.RollAction.second) {
                AnimatedRoll()
            }
        }.ifLet(\.rollDetails, action: /DiceActionFeature.StepAction.rollDetails) {
            DiceCalculator()
        }
    }
}

extension DiceActionFeature.State {
    static let nullInstance = Self(creatureName: "", action: DiceAction(title: "", subtitle: "", steps: []))
}
