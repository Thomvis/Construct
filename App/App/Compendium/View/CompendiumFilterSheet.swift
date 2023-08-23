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
                        LabeledContent {
                            Menu {
                                if let realmsWithDocuments = viewStore.state.realmsWithDocuments.value {
                                    let selection = viewStore.state.current.selectedSource

                                    Button(action: {
                                        viewStore.send(.selectedSource(nil))
                                    }, label: {
                                        Label("All", systemImage: sourcesMenuIcon(selection, nil, nil))
                                    })

                                    ForEach(realmsWithDocuments) { realm in
                                        Menu {
                                            Button(action: {
                                                viewStore.send(
                                                    .selectedSource(
                                                        CompendiumFilterSheetState.Values.SelectedSource(
                                                            realmId: realm.realm.id,
                                                            documentId: nil,
                                                            displayName: realm.realm.displayName
                                                        )
                                                    )
                                                )
                                            }, label: {
                                                Label("All", systemImage: sourcesMenuIcon(selection, realm.id, nil, true))
                                            })

                                            Divider()

                                            ForEach(realm.documents) { document in
                                                Button(action: {
                                                    viewStore.send(
                                                        .selectedSource(
                                                            CompendiumFilterSheetState.Values.SelectedSource(
                                                                realmId: realm.id,
                                                                documentId: document.id,
                                                                displayName: document.displayName
                                                            )
                                                        )
                                                    )
                                                }, label: {
                                                    Label(document.displayName, systemImage: sourcesMenuIcon(selection, realm.id, document.id))
                                                })
                                            }
                                        } label: {
                                            Label(realm.realm.displayName, systemImage: sourcesMenuIcon(selection, realm.id, nil))
                                        }
                                    }
                                } else {
                                    Text("Loading...")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if let selectedSource = viewStore.state.current.selectedSource {
                                        Text(selectedSource.displayName)
                                    } else {
                                        Text("All")
                                    }

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.footnote)
                                }
                                .fontWeight(.regular)
                                .padding(.trailing, 12)
                            }
                            .frame(minHeight: 35)
                        } label: {
                            Text("Sources")
                        }
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
        .onAppear {
            viewStore.send(.realmsWithDocuments(.startLoading))
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

    func sourcesMenuIcon(
        _ selection: CompendiumFilterSheetState.Values.SelectedSource?,
        _ realmId: CompendiumRealm.Id?,
        _ documentId: CompendiumSourceDocument.Id?,
        _ allInRealmItem: Bool = false
    ) -> String {
        let fullMatch = "checkmark.square"
        let partialMatch = "minus.square"
        let noMatch = "square"

        guard let selection else {
            return realmId == nil && documentId == nil ? fullMatch : noMatch
        }

        if selection.realmId == realmId {
            if documentId == nil && selection.documentId != nil {
                return allInRealmItem ? noMatch : partialMatch
            }
            return selection.documentId == documentId ? fullMatch : noMatch
        }

        return noMatch
    }
}

struct CompendiumFilterSheetState: Equatable {
    typealias AsyncRealmsWithDocuments = Async<[RealmWithDocuments], Error>

    let challengeRatings = crToXpMapping.keys.sorted()
    let allAllowedItemTypes: [CompendiumItemType]

    let initial: Values
    var current: Values

    var realmsWithDocuments: AsyncRealmsWithDocuments = .initial

    init() {
        self.allAllowedItemTypes = CompendiumItemType.allCases
        self.initial = Values()
        self.current = Values()
    }

    struct Values: Equatable {
        var selectedSource: SelectedSource?
        var itemType: CompendiumItemType?
        var minMonsterCR: Fraction?
        var maxMonsterCR: Fraction?
        var monsterType: MonsterType?

        struct SelectedSource: Equatable {
            var realmId: CompendiumRealm.Id
            var documentId: CompendiumSourceDocument.Id?

            var displayName: String
        }
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
            itemType: current.itemType,
            minMonsterCR: filters.contains(.minMonsterCR) ? current.minMonsterCR : nil,
            maxMonsterCR: filters.contains(.maxMonsterCR) ? current.maxMonsterCR : nil,
            monsterType: filters.contains(.monsterType) ? current.monsterType : nil
        )
    }

    typealias Filter = CompendiumFilters.Property

    struct RealmWithDocuments: Equatable, Identifiable {
        let realm: CompendiumRealm
        let documents: [CompendiumSourceDocument]

        var id: CompendiumRealm.Id { realm.id }
    }
}

extension CompendiumSourceDocument: Identifiable { }

enum CompendiumFilterSheetAction {
    case selectedSource(CompendiumFilterSheetState.Values.SelectedSource?)
    case itemType(CompendiumItemType?)
    case minMonsterCR(Double)
    case maxMonsterCR(Double)
    case monsterType(MonsterType?)
    case editing(CompendiumFilterSheetState.Filter, Bool)
    case clear(CompendiumFilterSheetState.Filter)
    case clearAll

    case realmsWithDocuments(CompendiumFilterSheetState.AsyncRealmsWithDocuments.Action)
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
            AnyReducer { state, action, _ in
            switch action {
            case .itemType(let type):
                state.current.itemType = type
            case .minMonsterCR(let v):
                state.minMonsterCrDouble = v
            case .maxMonsterCR(let v):
                state.maxMonsterCrDouble = v
            case .selectedSource(let s):
                state.current.selectedSource = s
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
            case .realmsWithDocuments: break // handled below
            }
            return .none
        },
        AsyncRealmsWithDocuments.reducer { (env: EnvironmentWithCompendiumMetadata) in
            do {
                let realms = try env.compendiumMetadata.realms()
                let documents = try env.compendiumMetadata.sourceDocuments()
                let realmsWithDocuments = realms.map { realm in
                    RealmWithDocuments(
                        realm: realm,
                        documents: documents.filter { $0.realmId == realm.id }
                    )
                }
                return Just(realmsWithDocuments).setFailureType(to: Swift.Error.self).eraseToAnyPublisher()
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }.pullback(state: \.realmsWithDocuments, action: /CompendiumFilterSheetAction.realmsWithDocuments, environment: { $0 })
    )
}

#if DEBUG
struct CompendiumFilterSheetPreview: PreviewProvider {
    static var previews: some View {
        CompendiumFilterSheet(store: Store(
            initialState: CompendiumFilterSheetState(),
            reducer: CompendiumFilterSheetState.reducer,
            environment: StandaloneActionResolutionEnvironment(
                compendiumMetadata: CompendiumMetadataKey.previewValue
            )
        )) { _ in

        }
    }
}

struct StandaloneActionResolutionEnvironment: CompendiumFilterSheetEnvironment {
    var compendiumMetadata: CompendiumMetadata
}
#endif
