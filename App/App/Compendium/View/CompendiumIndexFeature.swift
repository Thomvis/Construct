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
import ComposableArchitecture
import Combine
import Helpers
import GameModels
import Compendium
import Persistence
import MechMuse
import DiceRollerFeature

typealias CompendiumIndexEnvironment = EnvironmentWithDatabase & EnvironmentWithCrashReporter & EnvironmentWithUUIDGenerator & EnvironmentWithCompendiumMetadata & CompendiumEntryDetailEnvironment

struct CompendiumIndexFeature: Reducer {
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

        @PresentationState var destination: Destination.State?
        var safari: SafariViewState?
        @PresentationState var alert: AlertState<Action.Alert>?
        @PresentationState var sheet: Sheet.State?

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

    struct Destination: Reducer {
        let environment: CompendiumIndexEnvironment

        enum State: Equatable {
            case itemDetail(CompendiumEntryDetailFeature.State)
        }

        enum Action: Equatable {
            case compendiumIndex(CompendiumIndexFeature.Action)
            case itemDetail(CompendiumEntryDetailFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.itemDetail, action: /Action.itemDetail) {
                CompendiumEntryDetailFeature(environment: environment)
            }
        }
    }

    struct Sheet: Reducer {
        let environment: CompendiumIndexEnvironment

        enum State: Equatable {
            case creatureEdit(CreatureEditFeature.State)
            case groupEdit(CompendiumItemGroupEditFeature.State)
            case compendiumImport(CompendiumImportFeature.State)
            case documents(CompendiumDocumentsFeature.State)
            case transfer(CompendiumItemTransferFeature.State)
        }

        enum Action: Equatable {
            case creatureEdit(CreatureEditFeature.Action)
            case groupEdit(CompendiumItemGroupEditFeature.Action)
            case compendiumImport(CompendiumImportFeature.Action)
            case documents(CompendiumDocumentsFeature.Action)
            case transfer(CompendiumItemTransferFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.creatureEdit, action: /Action.creatureEdit) {
                CreatureEditFeature()
            }
            Scope(state: /State.groupEdit, action: /Action.groupEdit) {
                CompendiumItemGroupEditFeature()
            }
            Scope(state: /State.compendiumImport, action: /Action.compendiumImport) {
                CompendiumImportFeature()
                    .dependency(\.database, environment.database)
                    .dependency(\.compendium, environment.compendium)
                    .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                    .dependency(\.uuid, UUIDGenerator(environment.generateUUID))
            }
            Scope(state: /State.documents, action: /Action.documents) {
                CompendiumDocumentsFeature()
                    .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                    .dependency(\.database, environment.database)
            }
            Scope(state: /State.transfer, action: /Action.transfer) {
                CompendiumItemTransferFeature()
                    .dependency(\.compendium, environment.compendium)
                    .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                    .dependency(\.database, environment.database)
            }
        }
    }

    let environment: CompendiumIndexEnvironment

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
                        let entry = CompendiumEntry(
                            group,
                            origin: .created(nil),
                            document: .init(CompendiumSourceDocument.homebrew)
                        )
                        try? environment.compendium.put(entry)

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
            case .destination(.presented(.itemDetail(.sheet(.creatureEdit(.didEdit))))):
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
                        for key in keys {
                            _ = try? environment.database.keyValueStore.remove(key)
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
        .ifLet(\.$destination, action: /Action.destination) {
            Destination(environment: environment)
        }
        .ifLet(\.$sheet, action: /Action.sheet) {
            Sheet(environment: environment)
        }

        Scope(state: \.results, action: /Action.results) {
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
                    let entries: [CompendiumEntry]
                    do {
                        entries = try environment.compendium.fetchCatching(CompendiumFetchRequest(
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
                        environment.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
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

public struct StandaloneCompendiumIndexEnvironment: CompendiumIndexEnvironment {
    public var database: Database
    public var crashReporter: CrashReporter
    public var generateUUID: @Sendable () -> UUID
    public var compendiumMetadata: CompendiumMetadata
    public var compendium: Compendium
    public var modifierFormatter: NumberFormatter
    public var mainQueue: AnySchedulerOf<DispatchQueue>
    public var diceLog: DiceLogPublisher
    public var canSendMail: () -> Bool
    public var sendMail: (FeedbackMailContents) -> Void
    public var mechMuse: MechMuse

    static func fromDependencies() -> Self {
        @Dependency(\.database) var database
        @Dependency(\.crashReporter) var crashReporter
        @Dependency(\.uuid) var uuid
        @Dependency(\.compendiumMetadata) var compendiumMetadata
        @Dependency(\.compendium) var compendium
        @Dependency(\.modifierFormatter) var modifierFormatter
        @Dependency(\.mainQueue) var mainQueue
        @Dependency(\.diceLog) var diceLog
        @Dependency(\.mailer) var mailer
        @Dependency(\.mechMuse) var mechMuse

        return StandaloneCompendiumIndexEnvironment(
            database: database,
            crashReporter: crashReporter,
            generateUUID: { uuid() },
            compendiumMetadata: compendiumMetadata,
            compendium: compendium,
            modifierFormatter: modifierFormatter,
            mainQueue: mainQueue,
            diceLog: diceLog,
            canSendMail: mailer.canSendMail,
            sendMail: mailer.sendMail,
            mechMuse: mechMuse
        )
    }
}
