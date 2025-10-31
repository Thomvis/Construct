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
import CasePaths
import Combine
import Helpers
import GameModels
import Compendium
import Persistence
import MechMuse
import DiceRollerFeature

typealias CompendiumIndexEnvironment = EnvironmentWithDatabase & EnvironmentWithCrashReporter & EnvironmentWithUUIDGenerator & EnvironmentWithCompendiumMetadata & CompendiumEntryDetailEnvironment

struct CompendiumIndexFeature: Reducer {
    struct State: NavigationStackSourceState, Equatable {

        typealias MS = MapState<Query.State, PagingData<CompendiumEntry>>
        typealias RS = RetainState<MS, LastResult>

        let title: String
        var properties: Properties

        var results: RS
        var suggestions: [CompendiumEntry]?
        
        var scrollTo: CompendiumEntry.Key? // the key of the entry to scroll to

        // Selection UI state
        var isSelecting: Bool = false
        var selectedKeys: Set<CompendiumItemKey> = []

        var presentedScreens: [NavigationDestination: NextScreen]
        var alert: AlertState<Action>?
        var sheet: Sheet?

        init(title: String, properties: State.Properties, results: State.RS, presentedScreens: [NavigationDestination: NextScreen] = [:], sheet: Sheet? = nil) {
        self.title = title
        self.properties = properties
        self.results = results
        self.presentedScreens = presentedScreens
        self.sheet = sheet

        properties.apply(to: &self.results.input.filters)
    }

    var localStateForDeduplication: Self {
        var res = self
        res.results.input = Query.State.nullInstance
        res.results.retained?.input = Query.State.nullInstance

            res.presentedScreens = presentedScreens.mapValues {
                switch $0 {
                case .compendiumIndex: return .compendiumIndex(State.nullInstance)
                case .itemDetail: return .itemDetail(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
                case .safariView: return .safariView(.nullInstance)
                }
            }
            res.sheet = sheet.map {
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

        var creatureEditSheet: CreatureEditFeature.State? {
            get {
                if case .creatureEdit(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .creatureEdit(newValue)
                }
            }
        }

        var groupEditSheet: CompendiumItemGroupEditFeature.State? {
            get {
                if case .groupEdit(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .groupEdit(newValue)
                }
            }
        }

        var compendiumImportSheet: CompendiumImportFeature.State? {
            get {
                if case .compendiumImport(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .compendiumImport(newValue)
                }
            }
        }

        var documentsSheet: CompendiumDocumentsFeature.State? {
            get {
                if case .documents(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .documents(newValue)
                }
            }
        }

        var transferSheet: CompendiumItemTransferFeature.State? {
            get {
                if case .transfer(let state)? = sheet {
                    return state
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    sheet = .transfer(newValue)
                }
            }
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

        enum NextScreen: Equatable {
            indirect case compendiumIndex(State)
            case itemDetail(CompendiumEntryDetailFeature.State)
            case safariView(SafariViewState)
        }

        enum Sheet: Equatable, Identifiable {
            // creatureEdit and groupEdit are used when adding a new creature/group
            case creatureEdit(CreatureEditFeature.State)
            case groupEdit(CompendiumItemGroupEditFeature.State)
            case compendiumImport(CompendiumImportFeature.State)
            case documents(CompendiumDocumentsFeature.State)
            case transfer(CompendiumItemTransferFeature.State)

            var id: String {
                switch self {
                case .creatureEdit(let s): return s.navigationStackItemStateId
                case .groupEdit(let s): return s.navigationStackItemStateId
                case .compendiumImport: return "import"
                case .documents: return "documents"
                case .transfer: return "transfer"
                }
            }
        }
    }

    enum Action: NavigationStackSourceAction, Equatable {

        typealias ResultsAction = MapAction<Query.State, Query.Action, PagingData<CompendiumEntry>, PagingDataAction<CompendiumEntry>>

        case results(ResultsAction)
        case scrollTo(CompendiumEntry.Key?)
        case onQueryTypeFilterDidChange([CompendiumItemType]?)
        case onAddButtonTap(CompendiumItemType)
        case onSearchOnWebButtonTap
        case onTransferSelectedMenuItemTap(TransferMode)
        case onDeleteSelectedRequested
        case onDeleteSelectedConfirmed
        case setSelecting(Bool)
        case clearSelection
        case setSelectedKeys(Set<CompendiumItemKey>)

        case setNextScreen(State.NextScreen?)
        indirect case nextScreen(NextScreenAction)
        case setDetailScreen(State.NextScreen?)
        indirect case detailScreen(NextScreenAction)

        indirect case alert(AlertState<Action>?)

        case setSheet(State.Sheet?)
        case creatureEditSheet(CreatureEditFeature.Action)
        case groupEditSheet(CompendiumItemGroupEditFeature.Action)
        case compendiumImportSheet(CompendiumImportFeature.Action)
        case documentsSheet(CompendiumDocumentsFeature.Action)
        case transferSheet(CompendiumItemTransferFeature.Action)

        static func presentScreen(_ destination: NavigationDestination, _ screen: State.NextScreen?) -> Self {
            switch destination {
            case .nextInStack: return .setNextScreen(screen)
            case .detail: return .setDetailScreen(screen)
            }
        }

        static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self {
            switch destination {
            case .nextInStack: return .nextScreen(action)
            case .detail: return .detailScreen(action)
            }
        }

        enum NextScreenAction: Equatable {
            case compendiumIndex(Action)
            case compendiumEntry(CompendiumEntryDetailFeature.Action)
        }

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
                    state.presentedNextSafariView = SafariViewState(
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
                case .onDeleteSelectedConfirmed:
                    return .run { [keys=state.selectedKeys] send in
                        for key in keys {
                            _ = try? environment.database.keyValueStore.remove(key)
                        }
                        await send(.results(.result(.reload(.currentCount))))
                        await send(.alert(nil))
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
                case .setNextScreen(let n):
                    state.presentedScreens[.nextInStack] = n
                case .setDetailScreen(let s):
                    state.presentedScreens[.detail] = s
                case .creatureEditSheet(CreatureEditFeature.Action.didAdd(let result)):
                    // adding a new creature (handled by CreatureEditView reducer)
                    if case let .compendium(entry) = result {
                        return .merge(
                            .send(.scrollTo(entry.key)),
                            .send(.results(.result(.reload(.all)))),
                            .send(.setSheet(nil))
                        )
                    } else {
                        return .send(.setSheet(nil))
                    }
                case .groupEditSheet(CompendiumItemGroupEditFeature.Action.onAddTap(let group)):
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
                        await send(.setSheet(nil))
                    }
                case .compendiumImportSheet(.importDidFinish(.some)):
                    return .send(.results(.result(.reload(.currentCount))))
                case .transferSheet(.onTransferDidSucceed):
                    return .merge(
                        .send(.results(.result(.reload(.currentCount)))),
                        .send(.setSheet(nil))
                    )
                case .nextScreen(.compendiumEntry(.didRemoveItem)),
                     .detailScreen(.compendiumEntry(.didRemoveItem)):
                    // creature removed
                    return .run { send in
                        await send(.setNextScreen(nil))

                        // Work-around: without the delay, `.setNextScreen(nil)` is not picked up
                        // (probably because .reload makes the NavigationLink disappear)
                        try await Task.sleep(for: .seconds(0.1))
                        await send(.results(.result(.reload(.currentCount))))
                    }
                case .nextScreen(.compendiumEntry(.didAddCopy)),
                     .detailScreen(.compendiumEntry(.didAddCopy)):
                    // creature copied, edited & added
                    return .send(.results(.result(.reload(.currentCount))))
                case .nextScreen(.compendiumEntry(.sheet(.creatureEdit(.didEdit)))),
                     .detailScreen(.compendiumEntry(.sheet(.creatureEdit(.didEdit)))):
                    // done editing an existing creature
                    return .send(.results(.result(.reload(.currentCount))))
                case .nextScreen(.compendiumEntry(.entry)),
                     .detailScreen(.compendiumEntry(.entry)):
                    // creature on the detail screen changed
                    return .send(.results(.result(.reload(.currentCount))))
                case .nextScreen, .detailScreen:
                    break
                case .alert(let s):
                    state.alert = s
                case .setSheet(let s):
                    state.sheet = s
                case .creatureEditSheet, .groupEditSheet, .compendiumImportSheet, .documentsSheet, .transferSheet: break // handled below
            }
            return .none
        }
        .ifLet(\.presentedNextItemDetail, action: /Action.nextScreen..Action.NextScreenAction.compendiumEntry) {
            CompendiumEntryDetailFeature(environment: environment)
        }
        .ifLet(\.presentedDetailItemDetail, action: /Action.detailScreen..Action.NextScreenAction.compendiumEntry) {
            CompendiumEntryDetailFeature(environment: environment)
        }
        .ifLet(\.presentedNextCompendiumIndex, action: /Action.nextScreen..Action.NextScreenAction.compendiumIndex) {
            CompendiumIndexFeature(environment: environment)
        }
        .ifLet(\.creatureEditSheet, action: /Action.creatureEditSheet) {
            CreatureEditFeature()
        }
        .ifLet(\.groupEditSheet, action: /Action.groupEditSheet) {
            CompendiumItemGroupEditFeature()
        }
        .ifLet(\.compendiumImportSheet, action: /Action.compendiumImportSheet) {
            CompendiumImportFeature()
                .dependency(\.database, environment.database)
                .dependency(\.compendium, environment.compendium)
                .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                .dependency(\.uuid, UUIDGenerator(environment.generateUUID))
        }
        .ifLet(\.documentsSheet, action: /Action.documentsSheet) {
            CompendiumDocumentsFeature()
                .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                .dependency(\.database, environment.database)
        }
        .ifLet(\.transferSheet, action: /Action.transferSheet) {
            CompendiumItemTransferFeature()
                .dependency(\.compendium, environment.compendium)
                .dependency(\.compendiumMetadata, environment.compendiumMetadata)
                .dependency(\.database, environment.database)
        }

        Scope(state: \.results, action: /Action.results) {
            Reduce(resultsReducer, environment: environment)
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

    let resultsReducer: AnyReducer<CompendiumIndexFeature.State.RS, CompendiumIndexFeature.Action.ResultsAction, CompendiumIndexEnvironment> = CompendiumIndexFeature.State.MS.reducer(
            inputReducer: AnyReducer { env in
                CompendiumIndexFeature.Query()
            }.pullback(
                state: \.self,
                action: /CompendiumIndexFeature.Query.Action.self,
                environment: { _ in () } // ignore environment, CompendiumIndexState.Query.reducer doesn't need it
            ),
        initialResultStateForInput: { _ in PagingData() },
        initialResultActionForInput: { _ in .didShowElementAtIndex(0) },
        resultReducerForInput: { query in
            return PagingData.reducer { (request, env: CompendiumIndexEnvironment) in
                let entries: [CompendiumEntry]
                do {
                    entries = try env.compendium.fetchCatching(CompendiumFetchRequest(
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
                    env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                    return .failure(PagingDataError(describing: error))
                }

                let didReachEnd = request.count.map { entries.count < $0 } ?? true
                return .success(.init(elements: entries, end: didReachEnd))
            }
        }
    ).retaining { mapState in
        if let elements = mapState.result.elements {
            return CompendiumIndexFeature.State.LastResult(input: mapState.input, entries: elements)
        }
        return nil
    }
}

extension CompendiumIndexFeature.State {
    static let nullInstance = CompendiumIndexFeature.State(
        title: "",
        properties: Properties(showImport: false, showAdd: false),
        results: .initial,
        presentedScreens: [:]
    )
}

extension CompendiumIndexFeature.State {
    struct LastResult: Equatable {
        var input: CompendiumIndexFeature.Query.State
        var entries: [CompendiumEntry]
    }
}

extension CompendiumIndexFeature.State.RS {
    static let initial = CompendiumIndexFeature.State.RS(wrapped: MapState(input: CompendiumIndexFeature.Query.State(text: nil, filters: nil, order: .title), result: .init()))

    static func initial(types: [CompendiumItemType]) -> CompendiumIndexFeature.State.RS {
        CompendiumIndexFeature.State.RS(wrapped: MapState(input: CompendiumIndexFeature.Query.State(text: nil, filters: CompendiumFilters(types: types), order: .title), result: .init()))
    }

    static func initial(type: CompendiumItemType) -> CompendiumIndexFeature.State.RS {
        initial(types: [type])
    }
}

extension CompendiumIndexFeature.State: NavigationStackItemState {
    var navigationStackItemStateId: String {
        title
    }

    var navigationTitle: String { title }
}

extension CompendiumIndexFeature.State.RS {
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
