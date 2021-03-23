//
//  DiceCalculatorView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 18/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture

struct DiceCalculatorView: View {
    static let buttonSpacing: CGFloat = 10

    var store: Store<DiceCalculatorState, DiceCalculatorAction>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.showDicePad == $1.showDicePad }) { viewStore in
            VStack {
                DiceExpressionView(store: self.store)
                Divider()

                if viewStore.showDicePad {
                    DicePadView(store: ViewStore(store)).transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                } else {
                    OutcomeView(store: store).transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                }
            }.onAppear {
                if viewStore.state.rollOnAppear && viewStore.state.result == nil {
                    viewStore.send(.onRerollButtonTap)
                }
            }
        }
    }
}

struct DiceCalculatorState: Equatable {
    let displayOutcomeExternally: Bool
    let rollOnAppear: Bool

    var expression: DiceExpression
    var result: RolledDiceExpression? = nil
    var intermediaryResult: RolledDiceExpression? = nil // contains values in rapid succession just after a new result it set

    var mode: Mode
    var showDice: Bool = false

    var previousExpressions: [DiceExpression] = []

    var entryContext: EntryContext = EntryContext(color: nil, subtract: false)

    func result(includingIntermediary: Bool) -> RolledDiceExpression? {
        if includingIntermediary {
            return intermediaryResult ?? result
        }
        return result
    }

    enum Mode: Equatable {
        case editingExpression
        case rollingExpression
    }

    struct EntryContext: Equatable {
        var color: Die.Color?
        var subtract: Bool
    }

    static func rollingExpression(_ expression: DiceExpression, rollOnAppear: Bool = false, prefilledResult: Int? = nil) -> DiceCalculatorState {
        DiceCalculatorState(
            displayOutcomeExternally: false,
            rollOnAppear: rollOnAppear,
            expression: expression,
            result: prefilledResult.map { .number($0) },
            mode: .rollingExpression,
            previousExpressions: [.number(0)]
        )
    }

    static func editingExpression(_ expression: DiceExpression = .number(0)) -> DiceCalculatorState {
        DiceCalculatorState(
            displayOutcomeExternally: false,
            rollOnAppear: false,
            expression: expression,
            mode: .editingExpression
        )
    }

    static var reducer = Reducer<DiceCalculatorState, DiceCalculatorAction, Environment> { state, action, env in
        switch action {
        case .mode(let m):
            state.mode = m
        case .onRerollButtonTap:
            if state.expression.diceCount == 0 {
                return Effect(value: .mode(.editingExpression))
                    .receive(on: env.mainQueue.animation())
                    .eraseToEffect()
            } else {
                state.result = state.expression.roll
                return Effect(value: .startGeneratingIntermediaryResults(state.expression))
            }
        case .onShowDiceButtonTap:
            state.showDice.toggle()
        case .onExpressionEditButtonTap:
            if state.mode == .rollingExpression {
                state.mode = .editingExpression
            }
        case .onExpressionEditUndoButtonTap:
            if let previousExpression = state.previousExpressions.popLast() {
                state.expression = previousExpression
            }
        case .onExpressionEditRollButtonTap:
            if state.mode == .editingExpression {
                state.result = state.expression.roll
                if !state.displayOutcomeExternally {
                    state.mode = .rollingExpression
                }

                return Effect(value: .startGeneratingIntermediaryResults(state.expression))
            }
        case .onResultDieTap(let idx):
            state.result?.rerollDice(idx)
        case .appendExpression(let e):
            state.previousExpressions.append(state.expression)
            let effectiveExpression = (state.entryContext.subtract ? e.opposite : e).color(state.entryContext.color)
            state.expression.append(effectiveExpression)

            state.result = nil
        case .onColorCycleButtonTap:
            let current = DiceCalculatorState.colors.firstIndex(of: state.entryContext.color) ?? 0
            state.entryContext.color = DiceCalculatorState.colors[(current + 1) % DiceCalculatorState.colors.count]
        case .onPlusMinusButtonTap:
            state.entryContext.subtract.toggle()
        case .clearExpression:
            state.expression = .number(0)
            state.previousExpressions = []

            state.result = nil
        case .startGeneratingIntermediaryResults(let expression):
            return Effect(value: .intermediaryResultsStep(expression, 6))
        case .intermediaryResultsStep(let expression, let remaining):
            guard expression == state.expression && remaining > 0 else {
                state.intermediaryResult = nil
                return .none
            }
            state.intermediaryResult = expression.roll

            return Effect(value: .intermediaryResultsStep(expression, remaining-1))
                .delay(for: 0.08, scheduler: env.mainQueue)
                .eraseToEffect()
        }
        return .none
    }
}

// Derrived values
extension DiceCalculatorState {

    var showMinimizedExpressionView: Bool {
        mode != .editingExpression
    }
    var showExpressionEditButton: Bool {
        mode != .editingExpression
    }

    var showExpressionEditUndoButton: Bool {
        !previousExpressions.isEmpty && mode == .editingExpression
    }

    var showDiceSummary: Bool {
        guard let result = result else { return false }
        return result.contributingNodeCount > 1 || result.dice.count > 1
    }

    var shouldCelebrateRoll: Bool {
        if let result = result {
            return result.total == expression.maximum && expression.minimum != expression.maximum
        }
        return false
    }

    var resultIsIntermediary: Bool {
        intermediaryResult != nil
    }

    var canRerollResult: Bool {
        if let result = result {
            return result.dice.count > 0
        }
        return false
    }

    var showDicePad: Bool {
        if case .editingExpression = mode {
            return true
        }
        return false
    }

    var modifierEntrySign: String {
        entryContext.subtract ? "-" : "+"
    }
}

enum DiceCalculatorAction: Hashable {
    case mode(DiceCalculatorState.Mode)

    case onRerollButtonTap
    case onShowDiceButtonTap
    case onExpressionEditButtonTap
    case onExpressionEditUndoButtonTap
    case onExpressionEditRollButtonTap
    case onResultDieTap(Int)

    case clearExpression
    case appendExpression(DiceExpression)
    case onColorCycleButtonTap
    case onPlusMinusButtonTap

    case startGeneratingIntermediaryResults(DiceExpression)
    case intermediaryResultsStep(DiceExpression, Int)
}

fileprivate struct DiceExpressionView: View {
    var store: Store<DiceCalculatorState, DiceCalculatorAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            HStack {
                viewStore.state.expression.text
                    .font(viewStore.state.showMinimizedExpressionView ? .body : .largeTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            viewStore.send(.onExpressionEditButtonTap)
                        }
                    }

                Spacer()
                if viewStore.state.showExpressionEditUndoButton {
                    SwiftUI.Button(action: { viewStore.send(.onExpressionEditUndoButtonTap) }) {
                        Image(systemName: "arrow.uturn.left").font(.title)
                    }.accentColor(Color(UIColor.systemRed))
                } else if viewStore.state.showExpressionEditButton {
                    Button(action: {
                        withAnimation(.spring()) {
                            viewStore.send(.onExpressionEditButtonTap)
                        }
                    }) {
                        Text("Edit")
                    }
                }
            }
        }
    }
}

struct OutcomeView: View {
    let store: Store<DiceCalculatorState, DiceCalculatorAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                if viewStore.state.showDice && viewStore.state.showDiceSummary {
                    IfLetStore(store.scope(state: { $0.result(includingIntermediary: true) })) { store in
                        ResultDetailView(store: store)
                            .opacity(viewStore.state.resultIsIntermediary ? 0.66 : 1.0)
                    }
                } else {
                    if let result = viewStore.state.result(includingIntermediary: true) {
                        VStack {
                            if viewStore.state.showDiceSummary {
                                diceSummary(result).animation(nil, value: result)
                            }
                            HStack {
                                if viewStore.state.shouldCelebrateRoll && !viewStore.state.resultIsIntermediary {
                                    Throphy()
                                }

                                Text("\(result.total)").font(.largeTitle)
                                    .animation(nil, value: result)

                                if viewStore.state.shouldCelebrateRoll && !viewStore.state.resultIsIntermediary {
                                    Throphy()
                                }
                            }
                            if viewStore.state.showDiceSummary {
                                diceSummary(result).opacity(0.0) // just to reserve space for symmetry
                            }
                        }
                        .opacity(viewStore.state.resultIsIntermediary ? 0.66 : 1.0)
                    } else {
                        Button(action: {
                            viewStore.send(.onRerollButtonTap)
                        }) {
                            Text("Roll").font(.largeTitle)
                        }
                        .transition(.identity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(
                TrailingButtons(store: viewStore)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            )
            .overlay(Group {
                Button(action: {
                    withAnimation {
                        viewStore.send(.onShowDiceButtonTap)
                    }
                }) {
                    Text(viewStore.state.showDice && viewStore.state.showDiceSummary ? "Hide dice" : "Show dice").font(.footnote)
                }
                .disabled(!viewStore.state.showDiceSummary)
                .frame(maxWidth: .infinity, alignment: .leading)
            })
        }
    }

    func Throphy() -> some View {
        Text("🏆").font(.largeTitle).transition(.asymmetric(insertion: AnyTransition.scale.combined(with: .opacity), removal: .opacity))
    }

    @ViewBuilder
    func diceSummary(_ expr: RolledDiceExpression) -> some View {
        expr.text.font(.footnote).lineLimit(nil).foregroundColor(Color(UIColor.tertiaryLabel))
    }

    struct TrailingButtons: View {
        @ObservedObject var store: ViewStore<DiceCalculatorState, DiceCalculatorAction>

        var body: some View {
            VStack {
                Button(action: { self.store.send(.onRerollButtonTap) }) {
                    Text("Re-roll").font(.footnote)
                }.disabled(!self.store.canRerollResult)
            }
        }
    }
}

struct ResultDetailView: View {
    let store: Store<RolledDiceExpression, DiceCalculatorAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                LazyVGrid(
                    columns: gridColumns(viewStore.state),
                    spacing: 8
                ) {
                    ForEach(Array(viewStore.state.dice.enumerated()), id: \.0) { (idx, die) in
                        SimpleButton(action: {
                            viewStore.send(.onResultDieTap(idx))
                        }) {
                            self.view(die, index: idx)
                        }
                    }

                    if viewStore.state.modifier > 0 {
                        Text("+ \(viewStore.state.modifier)").bold()
                    } else if viewStore.state.modifier < 0 {
                        Text("- \(viewStore.state.modifier * -1)").bold()
                    }
                }.padding(10)

                Text("Tap a die to re-roll").font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
    }

    func gridColumns(_ expression: RolledDiceExpression) -> [GridItem] {
        let count = expression.dice.count + (expression.modifier != 0 ? 1 : 0)
        return Array(repeating: GridItem(.fixed(45)), count: min(count, 3))
    }

    func view(_ die: RolledDie, index idx: Int) -> some View {
        return Text("\(die.value)")
            .bold().underline(die.value == die.die.sides)
            .frame(width: 44, height: 44)
            .background(((die.die.color?.UIColor).map(Color.init) ?? Color(UIColor.systemGray5)).cornerRadius(4))
    }

}

fileprivate struct DicePadView: View {
    @ObservedObject var store: ViewStore<DiceCalculatorState, DiceCalculatorAction>

    var body: some View {
        VStack(spacing: DiceCalculatorView.buttonSpacing) {
            HStack(spacing: DiceCalculatorView.buttonSpacing) {
                CycleColorButton(action: { self.store.send(.onColorCycleButtonTap) }, color: self.store.entryContext.color).buttonStyle(FnButtonStyle())
                PlusMinusToggleButton(subtract: store.entryContext.subtract, toggle: {
                    self.store.send(.onPlusMinusButtonTap)
                }).buttonStyle(FnButtonStyle())
                makeFnButton(action: { self.store.send(.clearExpression)}, "Clear")
            }

            HStack(spacing: DiceCalculatorView.buttonSpacing) {
                makeButton("1d20", .dice(count: 1, die: .d20))
                makeButton("1d100", .dice(count: 1, die: .d100))
                makeButton("\(store.modifierEntrySign)1", .number(1))
            }

            HStack(spacing: DiceCalculatorView.buttonSpacing) {
                makeButton("1d10", .dice(count: 1, die: .d10))
                makeButton("1d12", .dice(count: 1, die: .d12))
                makeButton("\(store.modifierEntrySign)2", .number(2))
            }

            HStack(spacing: DiceCalculatorView.buttonSpacing) {
                makeButton("1d6", .dice(count: 1, die: .d6))
                makeButton("1d8", .dice(count: 1, die: .d8))
                makeButton("\(store.modifierEntrySign)5", .number(5))
            }
            HStack(spacing: DiceCalculatorView.buttonSpacing) {
                makeButton("1d2", .dice(count: 1, die: .d2))
                makeButton("1d4", .dice(count: 1, die: .d4))
                Button(action: {
                    withAnimation(.spring()) {
                        self.store.send(.onExpressionEditRollButtonTap)
                    }
                }) {
                    Text("Roll")
                }
                .buttonStyle(ButtonStyle(color: Color(UIColor.systemBlue).opacity(0.5)))
                .disabled(store.state.expression.diceCount == 0)
                .opacity(store.state.expression.diceCount == 0 ? 0.33 : 1.0)
            }
        }
    }

    func makeButton(_ text: String, _ expression: DiceExpression) -> some View {
        Button(action: { self.store.send(.appendExpression(expression)) }) {
            Text(text)
        }.buttonStyle(ButtonStyle())
    }

    func makeFnButton(action: @escaping () -> Void, _ text: String) -> some View {
        Button(action: action) {
            Text(text)
        }.buttonStyle(FnButtonStyle())
    }

    struct FnButtonStyle: SwiftUI.ButtonStyle {
        let color: Color

        init(color: Color = Color(UIColor.systemGray5)) {
            self.color = color
        }

        func makeBody(configuration: Self.Configuration) -> some View {
            configuration.label
                .font(.subheadline)
                .frame(width: 70, height: 44)
                .background((configuration.isPressed ? color.opacity(0.5) : color).cornerRadius(22))
        }
    }

}

fileprivate struct PlusMinusToggleButton: View {

    let subtract: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: "plus.rectangle" + (!subtract ? ".fill" : ""))
                Image(systemName: "minus.rectangle" + (subtract ? ".fill" : ""))
            }
        }
    }

}

extension DiceCalculatorState {
    static let colors: [Die.Color?] = [nil] + Die.Color.allCases.map(Optional.some)
}

fileprivate struct CycleColorButton: View {

    var action: () -> Void
    var color: Die.Color?

    var body: some View {
        let effectiveColor: Color = (color?.UIColor).map(Color.init) ?? Color(UIColor.label)
        return Button(action: action) {
            return effectiveColor
                .cornerRadius(15)
                .frame(width: 30, height: 30)
        }
    }
}

extension DiceExpression {
    var text: Text {
        switch self {
        case .dice(let count, let die):
            return Text("\(count)d\(die.sides)").foregroundColor((die.color?.UIColor).map(Color.init))
        case .compound(let lhs, let op, let rhs):
            return lhs.text + Text(op.string) + rhs.text
        case .number(let n):
            return Text("\(n)")
        }
    }
}

extension RolledDiceExpression {
    var text: Text {
        switch self {
        case .dice(let die, let values):
            return Text("(" + values.map({ "\($0)" }).joined(separator: ", ") + ")").foregroundColor((die.color?.UIColor).map(Color.init) ?? Color(UIColor.tertiaryLabel))
                + Text("/\(die.sides)").foregroundColor(Color(UIColor.quaternaryLabel))
        case .compound(let lhs, let op, let rhs):
            return lhs.text + Text(" \(op.string) ") + rhs.text
        case .number(let n):
            return Text("\(n)")
        }
    }
}

struct ButtonStyle: SwiftUI.ButtonStyle {
    let color: Color

    init(color: Color = Color(UIColor.systemGray3)) {
        self.color = color
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(width: 70, height: 70)
            .background(GeometryReader { proxy in
                self.shapeHelper(size: proxy.size, configuration: configuration)
            })
    }

    func shapeHelper(size: CGSize, configuration: Self.Configuration) -> some View {
        let radius = min(size.width, size.height)
        return (configuration.isPressed ? self.color.opacity(0.5) : self.color).cornerRadius(radius/2)
    }
}
