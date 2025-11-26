import Foundation
import SwiftUI
import ComposableArchitecture
import DiceRollerFeature

@Reducer
public struct NumberPadFeature {
    @ObservableState
    public struct State: Equatable {
        fileprivate var digits: [Int]

        var value: Int {
            digits.reduce(0) { accumulator, element in
                (accumulator * 10) + element
            }
        }

        public init(value: Int) {
            var digits: [Int] = []
            var remainder = value
            while remainder > 0 {
                let digit = remainder % 10
                digits.insert(digit, at: 0)
                remainder = (remainder - digit) / 10
            }
            self.digits = digits
        }
    }

    public enum Action: Equatable {
        case numberButtonTap(Int)
        case deleteButtonTap
    }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .numberButtonTap(let digit):
            state.digits.append(digit)
            state.digits = Array(state.digits.drop(while: { $0 == 0 }))
        case .deleteButtonTap:
            _ = state.digits.popLast()
        }
        return .none
    }
}

struct NumberPadView: View {
    let store: StoreOf<NumberPadFeature>

    init(store: StoreOf<NumberPadFeature>) {
        self.store = store
    }

    var body: some View {
        VStack {
            HStack {
                Text("\(store.value)")
                    .font(.largeTitle)
                    .animation(.none, value: store.value)
                Spacer()
                Button {
                    store.send(.deleteButtonTap)
                } label: {
                    Image(systemName: "delete.left").font(.title)
                }
                .accentColor(Color(UIColor.systemRed))
                .keyboardShortcut(.delete, modifiers: [])
            }

            Divider()

            VStack(spacing: DiceCalculatorView.buttonSpacing) {
                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("7", 7).keyboardShortcut("7", modifiers: [])
                    makeButton("8", 8).keyboardShortcut("8", modifiers: [])
                    makeButton("9", 9).keyboardShortcut("9", modifiers: [])
                }

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("4", 4).keyboardShortcut("4", modifiers: [])
                    makeButton("5", 5).keyboardShortcut("5", modifiers: [])
                    makeButton("6", 6).keyboardShortcut("6", modifiers: [])
                }

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("1", 1).keyboardShortcut("1", modifiers: [])
                    makeButton("2", 2).keyboardShortcut("2", modifiers: [])
                    makeButton("3", 3).keyboardShortcut("3", modifiers: [])
                }

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("--", 0).opacity(0)
                    makeButton("0", 0).keyboardShortcut("0", modifiers: [])
                    makeButton("--", 0).opacity(0)
                }
            }
        }
    }

    private func makeButton(_ text: String, _ value: Int) -> some View {
        Button {
            store.send(.numberButtonTap(value))
        } label: {
            Text(text)
        }
        .buttonStyle(DiceCalculator.ButtonStyle())
    }
}
