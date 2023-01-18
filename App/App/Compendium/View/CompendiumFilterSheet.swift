//
//  CompendiumFilterSheet.swift
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
import GameModels

struct CompendiumFilterSheet: View {
    var store: Store<CompendiumFilterSheetState, CompendiumFilterSheetAction>
    @ObservedObject var viewStore: ViewStore<CompendiumFilterSheetState, CompendiumFilterSheetAction>

    let onApply: (CompendiumFilterSheetState.Values) -> Void

    init(store: Store<CompendiumFilterSheetState, CompendiumFilterSheetAction>, onApply: @escaping (CompendiumFilterSheetState.Values) -> Void) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    SectionContainer {
                        LabeledContent {
                            Picker("Type", selection: viewStore.binding(get: \.current.itemType, send: CompendiumFilterSheetAction.itemType).animation()) {
                                Text("All").tag(Optional<CompendiumItemType>.none)
                                ForEach(viewStore.state.allAllowedItemTypes, id: \.rawValue) { type in
                                    Text("\(type.localizedScreenDisplayName)").tag(Optional.some(type))
                                }
                            }
                        } label: {
                            Text("Kind")
                        }
                    }
                    .bold()
                    .padding(8)

                    with(Double(viewStore.state.challengeRatings.count-1)) { crRangeMax in
                        if viewStore.state.compatibleFilters.contains(.minMonsterCR) {
                            SectionContainer(title: "Minimum CR", accessory: clearButton(for: .minMonsterCR)) {
                                HStack {
                                    Text(viewStore.state.minMonsterCrString).frame(width: 30)
                                    Slider(value: viewStore.binding(get: \.minMonsterCrDouble, send: { .minMonsterCR($0) }), in: 0.0...crRangeMax, step: 1.0, onEditingChanged: onEditingChanged(.minMonsterCR))
                                        .environment(\.layoutDirection, .rightToLeft)
                                }
                            }
                        }

                        if viewStore.state.compatibleFilters.contains(.maxMonsterCR) {
                            SectionContainer(title: "Maximum CR", accessory: clearButton(for: .maxMonsterCR)) {
                                HStack {
                                    Text(viewStore.state.maxMonsterCrString).frame(width: 30)
                                    Slider(value: viewStore.binding(get: \.maxMonsterCrDouble, send: { .maxMonsterCR($0) }), in: 0.0...crRangeMax, step: 1.0, onEditingChanged: onEditingChanged(.maxMonsterCR))
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .autoSizingSheetContent()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    self.onApply(self.viewStore.state.effectiveCurrentValues)
                }) {
                    Text("Apply").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewStore.state.hasChanges())
                .padding(8)
                .autoSizingSheetContent(constant: 100)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        self.viewStore.send(.clearAll)
                    }) {
                        Text("Clear all")
                    }
                    .disabled(viewStore.effectiveCurrentValues == .init())
                }
            }
        }
    }

    func onEditingChanged(_ filter: CompendiumFilterSheetState.Filter) -> (Bool) -> Void {
        return { b in
            self.viewStore.send(.editing(filter, b))
        }
    }

    func clearButton(for filter: CompendiumFilterSheetState.Filter) -> some View {
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

struct CompendiumFilterSheetState: Equatable {
    let challengeRatings = crToXpMapping.keys.sorted()
    let allAllowedItemTypes: [CompendiumItemType]

    let initial: Values
    var current: Values

    init() {
        self.allAllowedItemTypes = CompendiumItemType.allCases
        self.initial = Values()
        self.current = Values()
    }

    struct Values: Equatable {
        var itemType: CompendiumItemType?
        var minMonsterCR: Fraction?
        var maxMonsterCR: Fraction?
    }

    var compatibleFilters: [Filter] {
        var result: [Filter] = []
        if (current.itemType == .monster) {
            // monster is included or there is no filter at all
            result.append(.minMonsterCR)
            result.append(.maxMonsterCR)
        }
        return result
    }

    /// Removes values that are not compatible with the currently selected type
    var effectiveCurrentValues: Values {
        let filters = compatibleFilters
        return Values(
            itemType: current.itemType,
            minMonsterCR: filters.contains(.minMonsterCR) ? current.minMonsterCR : nil,
            maxMonsterCR: filters.contains(.maxMonsterCR) ? current.maxMonsterCR : nil
        )
    }

    typealias Filter = CompendiumIndexState.Query.Filters.Property
}

enum CompendiumFilterSheetAction {
    case itemType(CompendiumItemType?)
    case minMonsterCR(Double)
    case maxMonsterCR(Double)
    case editing(CompendiumFilterSheetState.Filter, Bool)
    case clear(CompendiumFilterSheetState.Filter)
    case clearAll
}

extension CompendiumFilterSheetState {
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
        case .itemType:
            return current.itemType != nil
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

    static var reducer: AnyReducer<Self, CompendiumFilterSheetAction, Environment> = AnyReducer { state, action, _ in
        switch action {
        case .itemType(let type):
            state.current.itemType = type
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
        case .clear(.itemType):
            state.current.itemType = nil
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
