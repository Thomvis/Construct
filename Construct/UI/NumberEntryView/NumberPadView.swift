//
//  NumberPadView.swift
//  Construct
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
                    makeButton("--", 0).opacity(0.0)
                    makeButton("0", 0).keyboardShortcut("0", modifiers: [])
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
            let v = remainder % 10
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
