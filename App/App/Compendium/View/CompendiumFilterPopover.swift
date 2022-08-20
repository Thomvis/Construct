//
//  CompendiumFilterPopover.swift
//  Construct
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Helpers
import SharedViews

struct CompendiumFilterPopover: View, Popover {
    var popoverId: AnyHashable { "CompendiumFilterPopover" }
    var store: Store<CompendiumFilterPopoverState, CompendiumFilterPopoverAction>
    @ObservedObject var viewStore: ViewStore<CompendiumFilterPopoverState, CompendiumFilterPopoverAction>

    let onApply: (CompendiumFilterPopoverState.Values) -> Void

    init(store: Store<CompendiumFilterPopoverState, CompendiumFilterPopoverAction>, onApply: @escaping (CompendiumFilterPopoverState.Values) -> Void) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.onApply = onApply
    }

    var body: some View {
        VStack {
            ZStack {
                Text("Filters").font(.headline)
                Button(action: {
                    self.viewStore.send(.clearAll)
                }) {
                    Text("Clear all")
                }.frame(maxWidth: .infinity, alignment: .trailing).disabled(!viewStore.state.hasAnyValue())
            }
            Divider()
            with(Double(viewStore.state.challengeRatings.count-1)) { crRangeMax in
                if viewStore.state.filters.contains(.minMonsterCR) {
                    SectionContainer(title: "Minimum CR", accessory: clearButton(for: .minMonsterCR)) {
                        HStack {
                            Text(viewStore.state.minMonsterCrString).frame(width: 30)
                            Slider(value: viewStore.binding(get: \.minMonsterCrDouble, send: { .minMonsterCR($0) }), in: 0.0...crRangeMax, step: 1.0, onEditingChanged: onEditingChanged(.minMonsterCR))
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                }

                if viewStore.state.filters.contains(.maxMonsterCR) {
                    SectionContainer(title: "Maximum CR", accessory: clearButton(for: .maxMonsterCR)) {
                        HStack {
                            Text(viewStore.state.maxMonsterCrString).frame(width: 30)
                            Slider(value: viewStore.binding(get: \.maxMonsterCrDouble, send: { .maxMonsterCR($0) }), in: 0.0...crRangeMax, step: 1.0, onEditingChanged: onEditingChanged(.maxMonsterCR))
                        }
                    }
                }
            }

            Divider()

            Button(action: {
                self.onApply(self.viewStore.state.current)
            }) {
                Text("Apply")
            }.disabled(!viewStore.state.hasChanges())
        }
    }

    func onEditingChanged(_ filter: CompendiumFilterPopoverState.Filter) -> (Bool) -> Void {
        return { b in
            self.viewStore.send(.editing(filter, b))
        }
    }

    func clearButton(for filter: CompendiumFilterPopoverState.Filter) -> some View {
        Group {
            if viewStore.state.hasValue(for: filter) {
                Button(action: {
                    self.viewStore.send(.clear(filter))
                }) {
                    Text("Clear").font(.footnote)
                }
            }
        }
    }

    func makeBody() -> AnyView {
        AnyView(self.eraseToAnyView)
    }
}

struct CompendiumFilterPopoverState: Equatable {
    let filters: [Filter]
    let challengeRatings = crToXpMapping.keys.sorted()

    let initial: Values
    var current: Values

    init() {
        self.filters = Filter.allCases
        self.initial = Values()
        self.current = Values()
    }

    struct Values: Equatable {
        var minMonsterCR: Fraction?
        var maxMonsterCR: Fraction?
    }

    typealias Filter = CompendiumIndexState.Query.Filters.Property
}

enum CompendiumFilterPopoverAction {
    case minMonsterCR(Double)
    case maxMonsterCR(Double)
    case editing(CompendiumFilterPopoverState.Filter, Bool)
    case clear(CompendiumFilterPopoverState.Filter)
    case clearAll
}

extension CompendiumFilterPopoverState {
    var minMonsterCrDouble: Double {
        get {
            if let fraction = current.minMonsterCR, let idx = challengeRatings.firstIndex(of: fraction) {
                return Double(challengeRatings.count-1-idx)
            }
            return Double(challengeRatings.count-1)
        }
        set {
            current.minMonsterCR = challengeRatings[challengeRatings.count-1-Int(newValue)]
        }
    }

    var maxMonsterCrDouble: Double {
        get {
            if let fraction = current.maxMonsterCR, let idx = challengeRatings.firstIndex(of: fraction) {
                return Double(idx)
            }
            return Double(challengeRatings.count-1)
        }
        set {
            current.maxMonsterCR = challengeRatings[Int(newValue)]
        }
    }

    var minMonsterCrString: String {
        current.minMonsterCR.map { $0.rawValue } ?? "--"
    }

    var maxMonsterCrString: String {
        current.maxMonsterCR.map { $0.rawValue } ?? "--"
    }

    func hasValue(for filter: Filter) -> Bool {
        switch filter {
        case .minMonsterCR:
            return current.minMonsterCR != nil
        case .maxMonsterCR:
            return current.maxMonsterCR != nil
        }
    }

    func hasAnyValue() -> Bool {
        Filter.allCases.map { hasValue(for: $0) }.firstIndex(of: true) != nil
    }

    func hasChanges() -> Bool {
        initial != current
    }

    static var reducer: Reducer<Self, CompendiumFilterPopoverAction, Environment> = Reducer { state, action, _ in
        switch action {
        case .minMonsterCR(let v):
            state.minMonsterCrDouble = v
        case .maxMonsterCR(let v):
            state.maxMonsterCrDouble = v
        case .editing(.minMonsterCR, false):
            if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                state.current.maxMonsterCR = max(minCr, maxCr)
            }
        case .editing(.maxMonsterCR, false):
            if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                state.current.minMonsterCR = min(minCr, maxCr)
            }
        case .editing: break
        case .clear(.minMonsterCR):
            state.current.minMonsterCR = nil
        case .clear(.maxMonsterCR):
            state.current.maxMonsterCR = nil
        case .clearAll:
            return Filter.allCases.publisher.map { f in
                .clear(f)
            }.eraseToEffect()
        }
        return .none
    }
}
