//
//  NumberPadView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct NumberPadView: View {
    var store: Store<NumberPadViewState, NumberPadViewAction>
    @ObservedObject var viewStore: ViewStore<NumberPadViewState, NumberPadViewAction>

    init(store: Store<NumberPadViewState, NumberPadViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var overwriteString: String {
        return "\(viewStore.value)"
    }

    var body: some View {
        VStack {
            HStack {
                Text(overwriteString)
                    .font(.largeTitle)
                    .animation(.none)
                Spacer()
                SwiftUI.Button(action: { self.viewStore.send(.deleteButtonTap) }) {
                    Image(systemName: "delete.left").font(.title)
                }.accentColor(Color(UIColor.systemRed))
            }

            Divider()

            VStack(spacing: DiceCalculatorView.buttonSpacing) {

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("7", 7)
                    makeButton("8", 8)
                    makeButton("9", 9)
                }

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("4", 4)
                    makeButton("5", 5)
                    makeButton("6", 6)
                }

                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("1", 1)
                    makeButton("2", 2)
                    makeButton("3", 3)
                }
                HStack(spacing: DiceCalculatorView.buttonSpacing) {
                    makeButton("--", 0).opacity(0.0)
                    makeButton("0", 0)
                    makeButton("--", 0).opacity(0.0)
                }
            }
        }
    }

    func makeButton(_ text: String, _ n: Int) -> some View {
        Button(action: { self.viewStore.send(.numberButtonTap(n)) }) {
            Text(text)
        }.buttonStyle(ButtonStyle())
    }
}

struct NumberPadViewState: Hashable {
    private var ints: [Int] = []
    var value: Int {
        ints.reduce(0) { seq, elem in (seq*10) + elem }
    }

    init(value: Int) {
        var ints: [Int] = []

        var remainder = value
        while remainder > 0 {
            let v = value % 10
            ints.insert(v, at: 0)
            remainder = (remainder - v) / 10
        }
        self.ints = ints
    }

    mutating func append(_ n: Int) {
        ints.append(n)
        ints = Array(ints.drop(while: { $0 == 0 })) // remove leading zeroes
    }

    mutating func deleteNumber() {
        _ = ints.popLast()
    }
}

enum NumberPadViewAction: Equatable {
    case numberButtonTap(Int)
    case deleteButtonTap
}

extension NumberPadViewState {
    static var reducer: Reducer<Self, NumberPadViewAction, Environment> = Reducer { state, action, _ in
        switch action {
        case .numberButtonTap(let n):
            state.append(n)
        case .deleteButtonTap:
            state.deleteNumber()
        }
        return .none
    }
}
