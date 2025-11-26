//
//  CompendiumIndexState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Combine
import Helpers
import GameModels
import Compendium
import Persistence
import MechMuse
import DiceRollerFeature

@Reducer
struct CompendiumIndexFeature {
    @ObservableState
    struct State: Equatable {

        typealias MappedResults = Map<Query, PagingData<CompendiumEntry>>
        typealias RetainedMappedResults = Retain<MappedResults, LastResult>

        let title: String
        var properties: Properties

        var results: RetainedMappedResults.State
        var suggestions: [CompendiumEntry]?
        
        var scrollTo: CompendiumEntry.Key? // the key of the entry to scroll to

        // Selection UI state
        var isSelecting: Bool = false
        var selectedKeys: Set<CompendiumItemKey> = []

        @Presents var destination: Destination.State?
        var safari: SafariViewState?
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var sheet: Sheet.State?
        
        // MARK: - Computed properties for view
        
        var resultsStatus: ResultsStatus {
            if let resValues = results.entries {
                return resValues.isEmpty ? .succeededWithoutResults : .succeededWithResults
            } else if results.error != nil {
                return .failedWithError
            } else {
                return .loadingInitialContent
            }
        }
        
        var showMenu: Bool { properties.showImport }
        var showAddButton: Bool { properties.showAdd }
        var itemTypeRestriction: [CompendiumItemType]? { properties.typeRestriction }
        var sourceRestriction: CompendiumFilters.Source? { properties.sourceRestriction }
        
        var currentItemTypeFilter: [CompendiumItemType]? {
            Self.computeItemTypeFilter(input: results.input, properties: properties)
        }
        
        static func computeItemTypeFilter(input: CompendiumIndexFeature.Query.State?, properties: Properties) -> [CompendiumItemType]? {
            if Set(input?.filters?.types ?? []) == Set(properties.typeRestriction ?? CompendiumItemType.allCases) {
                return nil
            } else {
                return input?.filters?.types
            }
        }
        
        var allAllowedItemTypes: [CompendiumItemType] {
            itemTypeRestriction ?? CompendiumItemType.allCases
        }
        
        var addableItemTypes: [CompendiumItemType] {
            (currentItemTypeFilter ?? CompendiumItemType.allCases).filter { [.monster, .character, .group].contains($0) }
        }
        
        /// Entries currently displayed
        var entries: [CompendiumEntry] {
            results.entries ?? []
        }
        
        /// Suggestions to show when no query is entered
        var displaySuggestions: [CompendiumEntry]? {
            let input = results.inputForEntries
            if input?.text?.nonEmptyString == nil && Set(input?.filters?.types ?? []) == Set(properties.typeRestriction ?? []) {
                return suggestions?.nonEmptyArray
            }
            return nil
        }
        
        /// Type filters to show when no query is entered
        var displayTypeFilters: [CompendiumItemType]? {
            let input = results.inputForEntries
            let typeFilter = Self.computeItemTypeFilter(input: input, properties: properties)
            return input?.text?.nonEmptyString == nil && typeFilter == nil
                ? (properties.typeRestriction ?? CompendiumItemType.allCases)
                : nil
        }
        
        var useNamedSections: Bool {
            displaySuggestions != nil || displayTypeFilters != nil
        }
        
        var isLoadingMoreEntries: Bool {
            results.isLoading
        }
        
        enum ResultsStatus: Hashable {
            case loadingInitialContent
            case succeededWithResults
            case succeededWithoutResults
            case failedWithError

            var isSuccess: Bool {
                self == .succeededWithResults || self == .succeededWithoutResults
            }
        }

        init(
            title: String,
            properties: State.Properties,
            results: RetainedMappedResults.State,
            destination: Destination.State? = nil,
            safari: SafariViewState? = nil,
            sheet: Sheet.State? = nil
        ) {
            self.title = title
            self.properties = properties
            self.results = results
            self._destination = PresentationState(wrappedValue: destination)
            self.safari = safari
            self._sheet = PresentationState(wrappedValue: sheet)

            properties.apply(to: &self.results.input.filters)
        }

        var localStateForDeduplication: Self {
            var res = self
            res.results.input = Query.State.nullInstance
            res.results.retained?.input = Query.State.nullInstance

            if let destination {
                res.destination = destination.nullInstance
            }
            if safari != nil {
                res.safari = .nullInstance
            }
            res.sheet = res.sheet.map {
                switch $0 {
                case .creatureEdit: return .creatureEdit(CreatureEditFeature.State.nullInstance)
                case .groupEdit: return .groupEdit(CompendiumItemGroupEditFeature.State.nullInstance)
                case .compendiumImport: return .compendiumImport(CompendiumImportFeature.State())
                case .documents: return .documents(CompendiumDocumentsFeature.State())
                case .transfer: return .transfer(CompendiumItemTransferFeature.State(mode: .copy, selection: .multipleFetchRequest(.init())))
                }
            }

            return res
        }

        struct Properties: Equatable {
            let showImport: Bool
            let showAdd: Bool
            let typeRestriction: [CompendiumItemType]?
            let sourceRestriction: CompendiumFilters.Source?

            var showSourceDocumentBadges: Bool = false

            public init(
                showImport: Bool,
                showAdd: Bool,
                typeRestriction: [CompendiumItemType]? = nil,
                sourceRestriction: CompendiumFilters.Source? = nil
            ) {
                self.showImport = showImport
                self.showAdd = showAdd
                self.typeRestriction = typeRestriction
                self.sourceRestriction = sourceRestriction
            }

            func apply(to filter: inout CompendiumFilters?) {
                if let typeRestriction {
                    filter = filter ?? CompendiumFilters()
                    filter?.types?.removeAll { !typeRestriction.contains($0) }
                }
                if let sourceRestriction {
                    filter = filter ?? CompendiumFilters()
                    filter?.source = sourceRestriction
                }
            }
        }

    }

    @CasePathable
    enum Action: Equatable {

        typealias ResultsAction = Map<Query, PagingData<CompendiumEntry>>.Action

        case results(ResultsAction)
        case scrollTo(CompendiumEntry.Key?)
        case onQueryTypeFilterDidChange([CompendiumItemType]?)
        case onAddButtonTap(CompendiumItemType)
        case onSearchOnWebButtonTap
        case onTransferSelectedMenuItemTap(TransferMode)
        case onDeleteSelectedRequested
        case setSelecting(Bool)
        case clearSelection
        case setSelectedKeys(Set<CompendiumItemKey>)

        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)
        case setSafari(SafariViewState?)

        case alert(PresentationAction<Alert>)

        enum Alert {
            case onDeleteSelectedConfirmed
        }

        case setSheet(Sheet.State?)
        case sheet(PresentationAction<Sheet.Action>)

        // Key-path support
        var results: ResultsAction? {
            get {
                guard case .results(let a) = self else { return nil }
                return a
            }
            set {
                guard case .results = self, let value = newValue else { return }
                self = .results(value)
            }
        }

        static func query(_ a: Query.Action) -> Action {
            return .results(.input(a))
        }
    }

    @Reducer
    enum Destination {
        case itemDetail(CompendiumEntryDetailFeature)
    }

    struct Sheet: Reducer {
        @CasePathable
        enum State: Equatable {
            case creatureEdit(CreatureEditFeature.State)
            case groupEdit(CompendiumItemGroupEditFeature.State)
            case compendiumImport(CompendiumImportFeature.State)
            case documents(CompendiumDocumentsFeature.State)
            case transfer(CompendiumItemTransferFeature.State)
        }

        @CasePathable
        enum Action: Equatable {
            case creatureEdit(CreatureEditFeature.Action)
            case groupEdit(CompendiumItemGroupEditFeature.Action)
            case compendiumImport(CompendiumImportFeature.Action)
            case documents(CompendiumDocumentsFeature.Action)
            case transfer(CompendiumItemTransferFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: \.creatureEdit, action: \.creatureEdit) {
                CreatureEditFeature()
            }
            Scope(state: \.groupEdit, action: \.groupEdit) {
                CompendiumItemGroupEditFeature()
            }
            Scope(state: \.compendiumImport, action: \.compendiumImport) {
                CompendiumImportFeature()
            }
            Scope(state: \.documents, action: \.documents) {
                CompendiumDocumentsFeature()
            }
            Scope(state: \.transfer, action: \.transfer) {
                CompendiumItemTransferFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .results: break
            case .scrollTo(let id):
                state.scrollTo = id
            case .onQueryTypeFilterDidChange(let typeFilter):
                if typeFilter == nil && state.properties.typeRestriction == nil {
                    return .send(.query(.onFiltersDidChange(CompendiumFilters())))
                } else {
                    let restrictions = state.properties.typeRestriction ?? CompendiumItemType.allCases
                    let new = typeFilter ?? CompendiumItemType.allCases
                    let withinRestrictions = new.filter { restrictions.contains($0 )}
                    return .send(.query(.onTypeFilterDidChange(withinRestrictions)))
                }
            case .onAddButtonTap(let type):
                let sourceDocument: CompendiumFilters.Source
                if let source = state.results.input.filters?.source {
                    sourceDocument = source
                } else {
                    sourceDocument = CompendiumFilters.Source(CompendiumSourceDocument.homebrew)
                }
                switch type {
                case .monster, .character:
                    guard let creatureType = type.creatureType else {
                        assertionFailure("Adding item of type \(type) is not supported yet")
                        break
                    }
                    state.sheet = .creatureEdit(CreatureEditFeature.State(
                        create: creatureType,
                        sourceDocument: sourceDocument
                    ))
                case .spell:
                    assertionFailure("Adding spells is not supported")
                    break
                case .group:
                    state.sheet = .groupEdit(CompendiumItemGroupEditFeature.State(mode: .create, group: CompendiumItemGroup(id: UUID().tagged(), title: "", members: [])))
                }

            case .onSearchOnWebButtonTap:
                let externalCompendium = DndBeyondExternalCompendium()
                state.safari = SafariViewState(
                    url: externalCompendium.searchPageUrl(
                        for: state.results.input.text ?? "",
                        types: state.results.input.filters?.types
                    )
                )
            case .onTransferSelectedMenuItemTap(let mode):
                state.sheet = .transfer(CompendiumItemTransferFeature.State(
                    mode: mode,
                    selection: .multipleKeys(Array(state.selectedKeys))
                ))
            case .onDeleteSelectedRequested:
                let count = state.selectedKeys.count
                state.alert = AlertState {
                    TextState("Delete \(count) item\(count == 1 ? "" : "s")?")
                } actions: {
                    ButtonState(role: .destructive, action: .onDeleteSelectedConfirmed) {
                        TextState("Delete")
                    }
                } message: {
                    TextState("This action cannot be undone.")
                }
            case .setSelecting(let selecting):
                state.isSelecting = selecting
                if !selecting {
                    state.selectedKeys.removeAll()
                }
            case .clearSelection:
                state.selectedKeys.removeAll()
            case .setSelectedKeys(let keys):
                state.selectedKeys = keys
            case .setDestination(let destination):
                state.destination = destination
            case .sheet(.presented(.creatureEdit(.didAdd(let result)))):
                // adding a new creature (handled by CreatureEditView reducer)
                state.sheet = nil
                if case let .compendium(entry) = result {
                    return .merge(
                        .send(.scrollTo(entry.key)),
                        .send(.results(.result(.reload(.all))))
                    )
                }
            case .sheet(.presented(.groupEdit(.onAddTap(let group)))):
                // adding a group
                return .run { send in
                    @Dependency(\.compendium) var compendium
                    let entry = CompendiumEntry(
                        group,
                        origin: .created(nil),
                        document: .init(CompendiumSourceDocument.homebrew)
                    )
                    try? compendium.put(entry)

                    await send(.results(.result(.reload(.all))))
                    await send(.scrollTo(entry.key))
                    await send(.sheet(.dismiss))
                }
            case .sheet(.presented(.compendiumImport(.importDidFinish(.some)))):
                return .send(.results(.result(.reload(.currentCount))))
            case .sheet(.presented(.transfer(.onTransferDidSucceed))):
                return .merge(
                    .send(.results(.result(.reload(.currentCount)))),
                    .send(.sheet(.dismiss))
                )
            case .destination(.presented(.itemDetail(.didRemoveItem))):
                // creature removed
                return .run { send in
                    await send(.setDestination(nil))

                    // Work-around: without the delay, `.setDestination(nil)` is not picked up
                    // (probably because .reload makes the NavigationLink disappear)
                    try await Task.sleep(for: .seconds(0.1))
                    await send(.results(.result(.reload(.currentCount))))
                }
            case .destination(.presented(.itemDetail(.didAddCopy))):
                // creature copied, edited & added
                return .send(.results(.result(.reload(.currentCount))))
            case .destination(.presented(.itemDetail(.sheet(.presented(.creatureEdit(.didEdit)))))):
                // done editing an existing creature
                return .send(.results(.result(.reload(.currentCount))))
            case .destination(.presented(.itemDetail(.entry))):
                // creature on the detail screen changed
                return .send(.results(.result(.reload(.currentCount))))
            case .destination(.dismiss):
                state.destination = nil
            case .destination:
                break
            case .setSafari(let safari):
                state.safari = safari
            case .alert(.presented(.onDeleteSelectedConfirmed)):
                state.alert = nil
                return .run { [keys=state.selectedKeys] send in
                    @Dependency(\.database) var database
                    for key in keys {
                        _ = try? database.keyValueStore.remove(key)
                    }
                    await send(.results(.result(.reload(.currentCount))))
                }
            case .alert(.dismiss):
                state.alert = nil
            case .setSheet(let s):
                state.sheet = s
            case .sheet(.dismiss):
                state.sheet = nil
            case .sheet:
                break
            }
            return .none
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$sheet, action: \.sheet) {
            Sheet()
        }

        Scope(state: \.results, action: \.results) {
            resultsReducer
        }
        .onChange(of: \.results.entries, { _, entries in
            Reduce { state, action in
                // If the list contains entries from multiple sources, we want to display the document badges
                if !state.properties.showSourceDocumentBadges, let entries, let first = entries.first {
                    if entries.dropFirst().first(where: { $0.document.id != first.document.id }) != nil {
                        state.properties.showSourceDocumentBadges = true
                    }
                }

                // remove keys from selection that are not displayed
                if let entries {
                    let displayedKeys = Set(entries.map { $0.item.key })
                    state.selectedKeys = state.selectedKeys.intersection(displayedKeys)
                }

                return .none
            }
        })

        // apply filter restrictions from the properties to the query
        Reduce { state, action in
            switch action {
            case .results(.input):
                state.properties.apply(to: &state.results.input.filters)
            default:
                break
            }
            return .none
        }
    }

    var resultsReducer: CompendiumIndexFeature.State.RetainedMappedResults {
        CompendiumIndexFeature.State.MappedResults(
            inputReducer: CompendiumIndexFeature.Query(),
            initialResultStateForInput: { _ in PagingData.State() },
            initialResultActionForInput: { _ in .didShowElementAtIndex(0) },
            resultReducerForInput: { query in
                PagingData { (request) in
                    @Dependency(\.compendium) var compendium
                    @Dependency(\.crashReporter) var crashReporter
                    
                    let entries: [CompendiumEntry]
                    do {
                        entries = try compendium.fetchCatching(CompendiumFetchRequest(
                            search: query.text?.nonEmptyString,
                            filters: query.filters,
                            order: query.order,
                            range: request.range
                        )).compactMap { result in
                            switch result {
                            case .success(let entry):
                                return entry
                            case .failure(DatabaseKeyValueStoreError.decodingError(_, let data, let error)):
                                return CompendiumEntry.error(String(customDumping: error), data: data)
                            case .failure: return nil
                            }
                        }
                    } catch {
                        assertionFailure("compendium.fetchAll failed with error: \(error)")
                        crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                        return .failure(PagingDataError(describing: error))
                    }

                    let didReachEnd = request.count.map { entries.count < $0 } ?? true
                    return .success(.init(elements: entries, end: didReachEnd))
                }
            }
        )
        .retaining { mapState in
            if let elements = mapState.result.elements {
                return CompendiumIndexFeature.State.LastResult(input: mapState.input, entries: elements)
            }
            return nil
        }
    }
}

extension CompendiumIndexFeature.State {
    static let nullInstance = CompendiumIndexFeature.State(
        title: "",
        properties: Properties(showImport: false, showAdd: false),
        results: .initial
    )
}

extension CompendiumIndexFeature.State {
    struct LastResult: Equatable {
        var input: CompendiumIndexFeature.Query.State
        var entries: [CompendiumEntry]
    }
}

extension CompendiumIndexFeature.State.RetainedMappedResults.State {
    static let initial = Self(wrapped: Map<CompendiumIndexFeature.Query, PagingData<CompendiumEntry>>.State(input: CompendiumIndexFeature.Query.State(text: nil, filters: nil, order: .title), result: .init()))

    static func initial(types: [CompendiumItemType]) -> Self {
        Self(wrapped: Map<CompendiumIndexFeature.Query, PagingData<CompendiumEntry>>.State(input: CompendiumIndexFeature.Query.State(text: nil, filters: CompendiumFilters(types: types), order: .title), result: .init()))
    }

    static func initial(type: CompendiumItemType) -> Self {
        initial(types: [type])
    }

    var entries: [CompendiumEntry]? {
        wrapped.result.elements ?? retained?.entries
    }

    /// Returns the input beloning to the Success value returned from `value` (which might be outdated compared
    /// to the current value for `input`.
    var inputForEntries: CompendiumIndexFeature.Query.State? {
        if wrapped.result.elements != nil {
            return wrapped.input
        }
        return retained?.input
    }

    var isLoading: Bool {
        wrapped.result.loadingState == .loading
    }

    var error: Swift.Error? {
        if case .error(let e) = wrapped.result.loadingState {
            return e
        }
        return nil
    }
}

extension CompendiumIndexFeature.State: DestinationTreeNode {}

extension CompendiumIndexFeature.Destination.State {
    var nullInstance: CompendiumIndexFeature.Destination.State {
        switch self {
        case .itemDetail:
            return .itemDetail(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
        }
    }
}

extension CompendiumIndexFeature.Destination.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .itemDetail(let state):
            return state.navigationNodes
        }
    }
}

extension CompendiumIndexFeature.Destination.State: Equatable {}
extension CompendiumIndexFeature.Destination.Action: Equatable {}

extension CompendiumIndexFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String {
        title
    }

    var navigationTitle: String { title }
}

extension CompendiumImportFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String {
        return "CompendiumImportFeature.State"
    }

    var navigationTitle: String {
        return "Import"
    }


}

extension CompendiumEntry {
    static func error(_ errorDump: String, data: Data) -> Self {
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        // attempt to parse stats
        let stats = json.flatMap { json in
            (json["item"] as? [String: Any])?["stats"] as? [String: Any]
        }.flatMap { statsJson in
            try? JSONSerialization.data(withJSONObject: statsJson)
        }.flatMap { statsData in
            try? DatabaseKeyValueStore.decoder.decode(StatBlock.self, from: statsData)
        } ?? apply(StatBlock.default) { stats in
            if let name = ((json?["item"] as? [String: Any])?["stats"] as? [String: Any])?["name"] as? String {
                stats.name = name
            }
        }

        var result = CompendiumEntry(
            Monster(
                realm: .init(CompendiumRealm.core.id),
                stats: stats,
                challengeRating: stats.challengeRating ?? 0
            ),
            origin: .created(nil),
            document: .init(.unspecifiedCore)
        )
        result.error = CompendiumEntry.Error(errorDump: errorDump, data: data)
        return result
    }
}
