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

struct CompendiumFilterSheet: View {
    @Bindable var store: StoreOf<CompendiumFilterSheetFeature>

    enum SourceScopeSelectionStyle {
        case none
        case partial
        case selected

        var systemImage: String {
            switch self {
            case .none: return "circle"
            case .partial: return "minus.circle.fill"
            case .selected: return "checkmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .none: return .secondary
            case .partial, .selected: return .accentColor
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    SectionContainer {
                        sourceScopeControl
                    }
                    .padding(8)
                    .disabled(store.sourcesSectionDisabled)

                    SectionContainer {
                        LabeledContent {
                            Picker("Type", selection: $store.current.itemType.sending(\.itemType).animation()) {
                                Text("All").tag(Optional<CompendiumItemType>.none)
                                ForEach(store.allAllowedItemTypes, id: \.rawValue) { type in
                                    Text("\(type.localizedScreenDisplayName)").tag(Optional.some(type))
                                }
                            }
                        } label: {
                            Text("Kind")
                                .bold()
                        }
                    }
                    .padding(8)

                    if store.compatibleFilters.contains(.monsterType) {
                        SectionContainer {
                            LabeledContent {
                                Picker(
                                    selection: $store.monsterType.sending(\.monsterType),
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
                                    .bold()
                            }
                        }
                        .padding(8)
                    }

                    with(Double(store.challengeRatings.count - 1)) { crRangeMax in
                        if store.compatibleFilters.contains(.minMonsterCR) {
                            SectionContainer(title: "Minimum CR", accessory: clearButton(for: .minMonsterCR)) {
                                HStack {
                                    Text(store.minMonsterCrString).frame(width: 30)
                                    Slider(
                                        value: $store.minMonsterCrDouble.sending(\.minMonsterCR),
                                        in: 0.0...crRangeMax,
                                        step: 1.0,
                                        onEditingChanged: onEditingChanged(.minMonsterCR)
                                    )
                                    .environment(\.layoutDirection, .rightToLeft)
                                }
                            }
                        }

                        if store.compatibleFilters.contains(.maxMonsterCR) {
                            SectionContainer(title: "Maximum CR", accessory: clearButton(for: .maxMonsterCR)) {
                                HStack {
                                    Text(store.maxMonsterCrString).frame(width: 30)
                                    Slider(
                                        value: $store.maxMonsterCrDouble.sending(\.maxMonsterCR),
                                        in: 0.0...crRangeMax,
                                        step: 1.0,
                                        onEditingChanged: onEditingChanged(.maxMonsterCR)
                                    )
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
                    store.send(.onApply)
                }) {
                    Text("Apply").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.state.hasChanges())
                .padding(8)
                .autoSizingSheetContent(constant: 100)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.send(.clearAll)
                    }) {
                        Text("Clear all")
                    }
                    .disabled(store.effectiveCurrentValues == .init())
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    var sourceScopeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                store.send(.setSourceScopesExpanded(!store.isSourceScopesExpanded), animation: .default)
            }) {
                LabeledContent {
                    HStack(alignment: .firstTextBaseline) {
                        Text(store.sourceScopeSummary)
                            .lineLimit(1)
                        
                        Image(systemName: store.isSourceScopesExpanded ? "chevron.up" : "chevron.down")
                            .contentTransition(.symbolEffect(.replace))
                            .font(.footnote)
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.trailing, 12) // align to other pickers
                } label: {
                    Text("Sources")
                        .bold()
                }
                .frame(minHeight: 36)
            }
            .buttonStyle(.plain)

            if store.isSourceScopesExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: {
                        store.send(.clear(.source))
                    }) {
                    sourceScopeRow(
                        title: "All sources",
                        selectionStyle: (store.current.sourceScopes?.isEmpty != false) ? .selected : .none,
                        emphasized: true,
                        indented: false
                    )
                    }
                    .buttonStyle(.plain)

                    if let realmsWithDocuments = store.realmsWithDocuments {
                        ForEach(realmsWithDocuments, id: \.realm.id) { row in
                            Button(action: {
                                store.send(.toggleRealmSourceScope(row.realm.id), animation: .default)
                            }) {
                            sourceScopeRow(
                                title: row.realm.displayName,
                                selectionStyle: {
                                    if store.selectedRealmIds.contains(row.realm.id) {
                                        return .selected
                                    }
                                    if store.selectedDocumentSources.contains(where: { $0.realm == row.realm.id }) {
                                        return .partial
                                    }
                                    return .none
                                }(),
                                emphasized: true,
                                indented: false
                            )
                            }
                            .buttonStyle(.plain)

                            ForEach(row.documents, id: \.id) { document in
                                let source = CompendiumFilters.Source(realm: row.realm.id, document: document.id)
                                Button(action: {
                                    store.send(.toggleDocumentSourceScope(source))
                                }) {
                                    sourceScopeRow(
                                        title: document.displayName,
                                        selectionStyle: (store.selectedRealmIds.contains(source.realm) || store.selectedDocumentSources.contains(source)) ? .selected : .none,
                                        emphasized: false,
                                        indented: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    func sourceScopeRow(title: String, selectionStyle: SourceScopeSelectionStyle, emphasized: Bool, indented: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectionStyle.systemImage)
                .foregroundStyle(selectionStyle.tint)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .fontWeight(emphasized ? .semibold : .regular)
            Spacer()
        }
        .frame(minHeight: 36)
        .padding(.leading, indented ? 24 : 0)
    }

    func onEditingChanged(_ filter: CompendiumFilterSheetFeature.State.Filter) -> (Bool) -> Void {
        return { isEditing in
            store.send(.editing(filter, isEditing))
        }
    }

    func clearButton(for filter: CompendiumFilterSheetFeature.State.Filter) -> some View {
        Group {
            if store.state.hasValue(for: filter) {
                Button(action: {
                    store.send(.clear(filter))
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

@Reducer
struct CompendiumFilterSheetFeature {
    @ObservableState
    struct State: Equatable {
        let challengeRatings = crToXpMapping.keys.sorted()
        let allAllowedItemTypes: [CompendiumItemType]
        let sourceRestriction: CompendiumFilters.Source?

        let initial: Values
        var current: Values

        var isSourceScopesExpanded = false

        typealias AsyncDocuments = Async<[CompendiumSourceDocument], EquatableError>
        var documents: AsyncDocuments.State = .initial
        typealias AsyncRealms = Async<[CompendiumRealm], EquatableError>
        var realms: AsyncRealms.State = .initial

        public init(
            allAllowedItemTypes: [CompendiumItemType] = CompendiumItemType.allCases,
            sourceRestriction: CompendiumFilters.Source? = nil,
            initial: Values = .init(),
            current: Values = .init(),
            documents: AsyncDocuments.State = .initial,
            realms: AsyncRealms.State = .initial
        ) {
            self.allAllowedItemTypes = allAllowedItemTypes
            self.sourceRestriction = sourceRestriction
            self.initial = initial
            self.current = current
            self.documents = documents
            self.realms = realms
        }

        init() {
            self.allAllowedItemTypes = CompendiumItemType.allCases
            self.sourceRestriction = nil
            self.initial = Values()
            self.current = Values()
        }

        struct Values: Equatable {
            var sourceScopes: [CompendiumFilters.SourceScope]?
            var itemType: CompendiumItemType?
            var minMonsterCR: Fraction?
            var maxMonsterCR: Fraction?
            var monsterType: MonsterType?
        }

        struct RealmWithDocuments: Equatable {
            let realm: CompendiumRealm
            let documents: [CompendiumSourceDocument]
        }

        var realmsWithDocuments: [RealmWithDocuments]? {
            guard let realms = realms.value, let documents = documents.value else {
                return nil
            }

            let documentsByRealm = Dictionary(grouping: documents, by: \.realmId)
            return realms.map { realm in
                RealmWithDocuments(
                    realm: realm,
                    documents: documentsByRealm[realm.id] ?? []
                )
            }
        }

        var selectedRealmIds: Set<CompendiumRealm.Id> {
            Set((current.sourceScopes ?? []).compactMap { scope in
                guard case let .realm(realmId) = scope else { return nil }
                return realmId
            })
        }

        var selectedDocumentSources: Set<CompendiumFilters.Source> {
            Set((current.sourceScopes ?? []).compactMap { scope in
                guard case let .document(source) = scope else { return nil }
                return source
            })
        }

        var sourceScopeSummary: String {
            let realmIds = selectedRealmIds
            let documentSources = selectedDocumentSources

            guard !realmIds.isEmpty || !documentSources.isEmpty else {
                return "All sources"
            }

            if realmIds.count == 1, documentSources.isEmpty,
               let realmId = realmIds.first,
               let realmName = realms.value?.first(where: { $0.id == realmId })?.displayName {
                return realmName
            }

            if realmIds.isEmpty, documentSources.count == 1,
               let source = documentSources.first,
               let documentName = documents.value?.first(where: { $0.realmId == source.realm && $0.id == source.document })?.displayName {
                return documentName
            }

            if !realmIds.isEmpty && !documentSources.isEmpty {
                return "\(realmIds.count) realm\(realmIds.count == 1 ? "" : "s"), \(documentSources.count) document\(documentSources.count == 1 ? "" : "s")"
            }

            if !realmIds.isEmpty {
                return "\(realmIds.count) realm\(realmIds.count == 1 ? "" : "s")"
            }

            return "\(documentSources.count) document\(documentSources.count == 1 ? "" : "s")"
        }

        mutating func toggleRealmSourceScope(_ realmId: CompendiumRealm.Id) {
            var realmIds = selectedRealmIds
            var documentSources = selectedDocumentSources

            if realmIds.contains(realmId) {
                realmIds.remove(realmId)
            } else {
                realmIds.insert(realmId)
                documentSources = Set(documentSources.filter { $0.realm != realmId })
            }

            current.sourceScopes = orderedSourceScopes(
                realmIds: realmIds,
                documentSources: documentSources
            ).nonEmptyArray
        }

        mutating func toggleDocumentSourceScope(_ source: CompendiumFilters.Source) {
            var documentSources = selectedDocumentSources
            var realmIds = selectedRealmIds
            let shouldRemoveDocumentSourceScope = documentSources.contains(source) || selectedRealmIds.contains(source.realm)
            if shouldRemoveDocumentSourceScope, realmIds.contains(source.realm) {
                // convert realm scope to individual document scopes
                let realmDocumentIds = realmsWithDocuments?
                    .first { $0.realm.id == source.realm }?
                    .documents.map { CompendiumFilters.Source($0) }
                
                if let realmDocumentIds {
                    documentSources.formUnion(realmDocumentIds)
                    realmIds.remove(source.realm)
                }
            }

            
            if shouldRemoveDocumentSourceScope {
                documentSources.remove(source)
            } else {
                documentSources.insert(source)
            }

            current.sourceScopes = orderedSourceScopes(
                realmIds: realmIds,
                documentSources: documentSources
            ).nonEmptyArray
        }

        func orderedSourceScopes(
            realmIds: Set<CompendiumRealm.Id>,
            documentSources: Set<CompendiumFilters.Source>
        ) -> [CompendiumFilters.SourceScope] {
            guard let realms = realms.value, let documents = documents.value else {
                return sortAndDeduplicate(
                    Array(realmIds).map(CompendiumFilters.SourceScope.realm)
                    + Array(documentSources).map(CompendiumFilters.SourceScope.document)
                )
            }

            var ordered: [CompendiumFilters.SourceScope] = []

            for realm in realms {
                if realmIds.contains(realm.id) {
                    ordered.append(.realm(realm.id))
                }

                for document in documents where document.realmId == realm.id {
                    let source = CompendiumFilters.Source(realm: realm.id, document: document.id)
                    if !realmIds.contains(realm.id), documentSources.contains(source) {
                        ordered.append(.document(source))
                    }
                }
            }

            let knownRealmIds = Set(realms.map(\.id))
            let unknownRealmIds = realmIds.subtracting(knownRealmIds)
                .sorted { $0.rawValue < $1.rawValue }
            ordered.append(contentsOf: unknownRealmIds.map(CompendiumFilters.SourceScope.realm))

            let knownSources = Set(documents.map {
                CompendiumFilters.Source(realm: $0.realmId, document: $0.id)
            })
            let unknownSources = documentSources.subtracting(knownSources)
                .sorted { ($0.realm.rawValue, $0.document.rawValue) < ($1.realm.rawValue, $1.document.rawValue) }
            ordered.append(contentsOf: unknownSources.map(CompendiumFilters.SourceScope.document))

            return ordered
        }

        func sortAndDeduplicate(_ scopes: [CompendiumFilters.SourceScope]) -> [CompendiumFilters.SourceScope] {
            var deduplicated: [CompendiumFilters.SourceScope] = []
            for scope in scopes where !deduplicated.contains(scope) {
                deduplicated.append(scope)
            }

            return deduplicated.sorted {
                sourceScopeSortKey($0) < sourceScopeSortKey($1)
            }
        }

        func sourceScopeSortKey(_ scope: CompendiumFilters.SourceScope) -> (Int, String, String) {
            switch scope {
            case .realm(let realmId):
                return (0, realmId.rawValue, "")
            case .document(let source):
                return (1, source.realm.rawValue, source.document.rawValue)
            }
        }

        var compatibleFilters: [Filter] {
            var result: [Filter] = []
            if current.itemType == .monster {
                result.append(.minMonsterCR)
                result.append(.maxMonsterCR)
                result.append(.monsterType)
            }
            return result
        }

        var effectiveCurrentValues: Values {
            let filters = compatibleFilters
            return Values(
                sourceScopes: current.sourceScopes,
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

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case setSourceScopesExpanded(Bool)
        case toggleRealmSourceScope(CompendiumRealm.Id)
        case toggleDocumentSourceScope(CompendiumFilters.Source)

        case itemType(CompendiumItemType?)
        case minMonsterCR(Double)
        case maxMonsterCR(Double)
        case monsterType(MonsterType?)
        case editing(State.Filter, Bool)
        case clear(State.Filter)
        case clearAll
        case onApply

        case documents(State.AsyncDocuments.Action)
        case realms(State.AsyncRealms.Action)
    }

    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerOf<Self> {
        CombineReducers {
            Reduce { state, action in
                switch action {
                case .onAppear:
                    return .merge(
                        .send(.documents(.startLoading)),
                        .send(.realms(.startLoading))
                    )
                case .setSourceScopesExpanded(let expanded):
                    state.isSourceScopesExpanded = expanded
                case .toggleRealmSourceScope(let realmId):
                    state.toggleRealmSourceScope(realmId)
                case .toggleDocumentSourceScope(let source):
                    state.toggleDocumentSourceScope(source)
                case .itemType(let type):
                    state.current.itemType = type
                case .minMonsterCR(let value):
                    state.minMonsterCrDouble = value
                case .maxMonsterCR(let value):
                    state.maxMonsterCrDouble = value
                case .monsterType(let monsterType):
                    state.monsterType = monsterType
                case .editing(.minMonsterCR, false):
                    if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                        state.current.maxMonsterCR = max(minCr, maxCr)
                    }
                case .editing(.maxMonsterCR, false):
                    if let minCr = state.current.minMonsterCR, let maxCr = state.current.maxMonsterCR {
                        state.current.minMonsterCR = min(minCr, maxCr)
                    }
                case .editing:
                    break
                case .clear(.source):
                    state.current.sourceScopes = nil
                case .clear(.itemType):
                    state.current.itemType = nil
                case .clear(.minMonsterCR):
                    state.current.minMonsterCR = nil
                case .clear(.maxMonsterCR):
                    state.current.maxMonsterCR = nil
                case .clear(.monsterType):
                    state.current.monsterType = nil
                case .clearAll:
                    return .merge(
                        State.Filter.allCases.map { filter in
                            .send(.clear(filter))
                        }
                    )
                case .onApply:
                    break
                case .documents, .realms:
                    break
                }
                return .none
            }

            Scope(state: \.documents, action: \.documents) {
                State.AsyncDocuments(compendiumMetadata: compendiumMetadata)
            }

            Scope(state: \.realms, action: \.realms) {
                State.AsyncRealms(compendiumMetadata: compendiumMetadata)
            }
        }
    }
}

extension CompendiumFilterSheetFeature.State {
    var minMonsterCrDouble: Double {
        get {
            if let fraction = current.minMonsterCR, let idx = challengeRatings.firstIndex(of: fraction) {
                return Double(challengeRatings.count - 1 - idx)
            }
            return Double(challengeRatings.count - 1)
        }
        set {
            current.minMonsterCR = challengeRatings[challengeRatings.count - 1 - Int(newValue)]
        }
    }

    var maxMonsterCrDouble: Double {
        get {
            if let fraction = current.maxMonsterCR, let idx = challengeRatings.firstIndex(of: fraction) {
                return Double(idx)
            }
            return Double(challengeRatings.count - 1)
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
            return current.sourceScopes?.isEmpty == false
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
}

#if DEBUG
struct CompendiumFilterSheetPreview: PreviewProvider {
    static var previews: some View {
        CompendiumFilterSheet(
            store: Store(initialState: CompendiumFilterSheetFeature.State()) {
                CompendiumFilterSheetFeature()
            }
        )
    }
}
#endif
