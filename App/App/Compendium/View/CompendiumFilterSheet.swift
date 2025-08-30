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
import Compendium
import Combine
import Tagged

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
                        CompendiumDocumentSelectionView(
                            store: store.scope(
                                state: \.documentSelection,
                                action: CompendiumFilterSheetAction.documentSelection
                            ),
                            label: "Sources"
                        )
                        .disabled(viewStore.state.sourcesSectionDisabled)
                    }
                    .bold()
                    .padding(8)

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

                    if viewStore.state.compatibleFilters.contains(.monsterType) {
                        SectionContainer {
                            LabeledContent {
                                Picker(
                                    selection: viewStore.binding(get: \.monsterType, send: CompendiumFilterSheetAction.monsterType),
                                    label: Text("Monster Type")
                                ) {
                                    Text("All").tag(Optional<MonsterType>.none)
                                    Divider()
                                    ForEach(MonsterType.allCases, id: \.rawValue) { type in
                                        Text(type.localizedDisplayName).tag(Optional.some(type))
                                    }
                                }
                            } label: {
                                Text("Monster Type")
                            }
                        }
                        .padding(8)
                    }

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

    func needsDividerBefore(
        _ source: (CompendiumFilterSheetState.Source),
        in sources: [CompendiumFilterSheetState.Source]
    ) -> Bool {
        guard let idx = sources.firstIndex(where: { $0.document == source.document }) else {
            return false
        }
        return idx == 0 || sources[idx-1].realm != source.realm
    }
}

struct CompendiumFilterSheetState: Equatable {
    typealias Source = (document: CompendiumSourceDocument, realm: CompendiumRealm)

    let challengeRatings = crToXpMapping.keys.sorted()
    let allAllowedItemTypes: [CompendiumItemType]
    let sourceRestriction: CompendiumFilters.Source?

    let initial: Values
    var current: Values

    var documentSelection: CompendiumDocumentSelectionFeature.State

    var documents: Async<[CompendiumSourceDocument], Error> = .initial
    var realms: Async<[CompendiumRealm], Error> = .initial

    var currentDocument: CompendiumSourceDocument? {
        guard let s = current.source else { return nil }
        return documents.value?.first(where: { $0.realmId == s.realm && $0.id == s.document })
    }


    public init(
        allAllowedItemTypes: [CompendiumItemType] = CompendiumItemType.allCases,
        sourceRestriction: CompendiumFilters.Source? = nil,
        initial: CompendiumFilterSheetState.Values = .init(),
        current: CompendiumFilterSheetState.Values = .init(),
        documents: Async<[CompendiumSourceDocument], any Error> = .initial,
        realms: Async<[CompendiumRealm], any Error> = .initial
    ) {
        self.allAllowedItemTypes = allAllowedItemTypes
        self.sourceRestriction = sourceRestriction
        self.initial = initial
        self.current = current
        self.documentSelection = .init(selectedSource: current.source)
        self.documents = documents
        self.realms = realms
    }


    init() {
        self.allAllowedItemTypes = CompendiumItemType.allCases
        self.sourceRestriction = nil
        self.initial = Values()
        self.current = Values()
        self.documentSelection = CompendiumDocumentSelectionFeature.State()
    }

    var allSources: [Source]? {
        guard let documents = documents.value, let realms = realms.value else {
            return nil
        }
        
        return documents.compactMap { d in
            realms.first(where: { $0.id == d.realmId }).map { r in
                (document: d, realm: r)
            }
        }
    }

    struct Values: Equatable {
        var source: CompendiumFilters.Source?
        var itemType: CompendiumItemType?
        var minMonsterCR: Fraction?
        var maxMonsterCR: Fraction?
        var monsterType: MonsterType?
    }

    var compatibleFilters: [Filter] {
        var result: [Filter] = []
        if (current.itemType == .monster) {
            // monster is included or there is no filter at all
            result.append(.minMonsterCR)
            result.append(.maxMonsterCR)
            result.append(.monsterType)
        }
        return result
    }

    /// Removes values that are not compatible with the currently selected type
    var effectiveCurrentValues: Values {
        let filters = compatibleFilters
        return Values(
            source: current.source,
            itemType: current.itemType,
            minMonsterCR: filters.contains(.minMonsterCR) ? current.minMonsterCR : nil,
            maxMonsterCR: filters.contains(.maxMonsterCR) ? current.maxMonsterCR : nil,
            monsterType: filters.contains(.monsterType) ? current.monsterType : nil
        )
    }

    var sourcesSectionDisabled: Bool {
        sourceRestriction != nil
    }

    typealias Filter = CompendiumFilters.Property
}

enum CompendiumFilterSheetAction {
    case itemType(CompendiumItemType?)
    case minMonsterCR(Double)
    case maxMonsterCR(Double)
    case monsterType(MonsterType?)
    case editing(CompendiumFilterSheetState.Filter, Bool)
    case clear(CompendiumFilterSheetState.Filter)
    case clearAll

    case documentSelection(CompendiumDocumentSelectionFeature.Action)
}

typealias CompendiumFilterSheetEnvironment = EnvironmentWithCompendiumMetadata

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

    var monsterType: MonsterType? {
        get {
            current.monsterType
        }
        set {
            current.monsterType = newValue
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
        case .source:
            return current.source != nil
        case .itemType:
            return current.itemType != nil
        case .minMonsterCR:
            return current.minMonsterCR != nil
        case .maxMonsterCR:
            return current.maxMonsterCR != nil
        case .monsterType:
            return current.monsterType != nil
        }
    }

    func hasAnyValue() -> Bool {
        Filter.allCases.map { hasValue(for: $0) }.firstIndex(of: true) != nil
    }

    func hasChanges() -> Bool {
        initial != current
    }

    static var reducer: AnyReducer<Self, CompendiumFilterSheetAction, CompendiumFilterSheetEnvironment> = AnyReducer.combine(
        AnyReducer { env in 
            CompendiumDocumentSelectionFeature()
                .dependency(\.compendiumMetadata, env.compendiumMetadata)
        }.pullback(
            state: \CompendiumFilterSheetState.documentSelection,
            action: /CompendiumFilterSheetAction.documentSelection
        )
        .onChange(of: \.documentSelection.selectedSource, perform: { s, state, action, env in
            state.current.source = s
            return .none
        }),
        AnyReducer { state, action, _ in
            switch action {
            case .itemType(let type):
                state.current.itemType = type
            case .minMonsterCR(let v):
                state.minMonsterCrDouble = v
            case .maxMonsterCR(let v):
                state.maxMonsterCrDouble = v
            case .monsterType(let t):
                state.monsterType = t
            case .editing(.minMonsterCR, false):
                if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                    state.current.maxMonsterCR = max(minCr, maxCr)
                }
            case .editing(.maxMonsterCR, false):
                if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                    state.current.minMonsterCR = min(minCr, maxCr)
                }
            case .editing: break
            case .clear(.source):
                state.current.source = nil
            case .clear(.itemType):
                state.current.itemType = nil
            case .clear(.minMonsterCR):
                state.current.minMonsterCR = nil
            case .clear(.maxMonsterCR):
                state.current.maxMonsterCR = nil
            case .clear(.monsterType):
                state.current.monsterType = nil
            case .clearAll:
                return Filter.allCases.publisher.map { f in
                    .clear(f)
                }.eraseToEffect()
            case .documentSelection:
                break
            }
            return .none
        }
    )
}

#if DEBUG
struct CompendiumFilterSheetPreview: PreviewProvider {
    static var previews: some View {
        CompendiumFilterSheet(store: Store(
            initialState: CompendiumFilterSheetState(),
            reducer: CompendiumFilterSheetState.reducer,
            environment: StandaloneCompendiumFilterSheetEnvironment(
                compendiumMetadata: CompendiumMetadataKey.previewValue
            )
        )) { _ in

        }
    }
}

struct StandaloneCompendiumFilterSheetEnvironment: EnvironmentWithCompendiumMetadata {
    let compendiumMetadata: CompendiumMetadata
}
#endif
