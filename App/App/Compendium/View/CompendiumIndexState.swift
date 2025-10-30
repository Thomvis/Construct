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

struct CompendiumIndexState: NavigationStackSourceState, Equatable {

    typealias MS = MapState<Query, PagingData<CompendiumEntry>>
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
    var alert: AlertState<CompendiumIndexAction>?
    var sheet: Sheet?

    init(title: String, properties: CompendiumIndexState.Properties, results: CompendiumIndexState.RS, presentedScreens: [NavigationDestination: NextScreen] = [:], sheet: Sheet? = nil) {
        self.title = title
        self.properties = properties
        self.results = results
        self.presentedScreens = presentedScreens
        self.sheet = sheet

        properties.apply(to: &self.results.input.filters)
    }

    var localStateForDeduplication: Self {
        var res = self
        res.results.input = Query.nullInstance
        res.results.retained?.input = Query.nullInstance

        res.presentedScreens = presentedScreens.mapValues {
            switch $0 {
            case .compendiumIndex: return .compendiumIndex(CompendiumIndexState.nullInstance)
            case .itemDetail: return .itemDetail(CompendiumEntryDetailFeature.State(entry: CompendiumEntry.nullInstance))
            case .safariView: return .safariView(.nullInstance)
            }
        }
        res.sheet = sheet.map {
            switch $0 {
            case .creatureEdit: return .creatureEdit(CreatureEditViewState.nullInstance)
            case .groupEdit: return .groupEdit(CompendiumItemGroupEditFeature.State.nullInstance)
            case .compendiumImport: return .compendiumImport(CompendiumImportFeature.State())
            case .documents: return .documents(CompendiumDocumentsFeature.State())
            case .transfer: return .transfer(CompendiumItemTransferFeature.State(mode: .copy, selection: .multipleFetchRequest(.init())))
            }
        }

        return res
    }

    var creatureEditSheet: CreatureEditViewState? {
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
        indirect case compendiumIndex(CompendiumIndexState)
        case itemDetail(CompendiumEntryDetailFeature.State)
        case safariView(SafariViewState)
    }

    enum Sheet: Equatable, Identifiable {
        // creatureEdit and groupEdit are used when adding a new creature/group
        case creatureEdit(CreatureEditViewState)
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

    static var reducer: AnyReducer<Self, CompendiumIndexAction, CompendiumIndexEnvironment> {
        return AnyReducer.combine(
            AnyReducer { env in
                CompendiumEntryDetailFeature(environment: env)
            }
            .optional()
            .pullback(state: \.presentedNextItemDetail, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry, environment: { $0 }),
            AnyReducer { env in
                CompendiumEntryDetailFeature(environment: env)
            }
            .optional()
            .pullback(state: \.presentedDetailItemDetail, action: /CompendiumIndexAction.detailScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry, environment: { $0 }),
            AnyReducer { state, action, env in
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
                        state.sheet = .creatureEdit(CreatureEditViewState(
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
                    return .run { [keys=state.selectedKeys, env] send in
                        for key in keys {
                            _ = try? env.database.keyValueStore.remove(key)
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
                case .creatureEditSheet(CreatureEditViewAction.didAdd(let result)):
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
                        try? env.compendium.put(entry)

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
            },
            MS.reducer(
                inputReducer: CompendiumIndexState.Query.reducer.pullback(
                    state: \.self,
                    action: /CompendiumIndexQueryAction.self,
                    environment: { _ in () } // ignore environment, CompendiumIndexState.Query.reducer doesn't need it
                ),
                initialResultStateForInput: { _ in PagingData() },
                initialResultActionForInput: { _ in .didShowElementAtIndex(0) },
                resultReducerForInput: { query in
                    PagingData.reducer { (request, env: CompendiumIndexEnvironment) in
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
                    return CompendiumIndexState.LastResult(input: mapState.input, entries: elements)
                }
                return nil
            }
            .pullback(state: \.results, action: /CompendiumIndexAction.results, environment: { $0 as CompendiumIndexEnvironment })
            .onChange(of: { $0.results.entries }, perform: { entries, state, _, env in
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
            }),
            // apply filter restrictions from the properties to the query
            AnyReducer { state, action, _ in
                switch action {
                case .results(.input):
                    state.properties.apply(to: &state.results.input.filters)
                default:
                    break
                }
                return .none
            },
            AnyReducer.lazy(CompendiumIndexState.reducer).optional().pullback(state: \.presentedNextCompendiumIndex, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumIndex, environment:  { $0 }),
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumIndexAction.creatureEditSheet, environment: { $0 }),
            AnyReducer { env in
                CompendiumItemGroupEditFeature(environment: env)
            }
            .optional().pullback(state: \.groupEditSheet, action: /CompendiumIndexAction.groupEditSheet, environment: { $0 }),
            AnyReducer { env in
                CompendiumImportFeature()
                    .dependency(\.database, env.database)
                    .dependency(\.compendium, env.compendium)
                    .dependency(\.compendiumMetadata, env.compendiumMetadata)
                    .dependency(\.uuid, UUIDGenerator(env.generateUUID))
            }
            .optional().pullback(state: \.compendiumImportSheet, action: /CompendiumIndexAction.compendiumImportSheet),
            AnyReducer { env in
                CompendiumDocumentsFeature()
                    .dependency(\.compendiumMetadata, env.compendiumMetadata)
                    .dependency(\.database, env.database)
            }
            .optional().pullback(state: \.documentsSheet, action: /CompendiumIndexAction.documentsSheet),
            AnyReducer { env in
                CompendiumItemTransferFeature()
                    .dependency(\.compendium, env.compendium)
                    .dependency(\.compendiumMetadata, env.compendiumMetadata)
                    .dependency(\.database, env.database)
            }
            .optional().pullback(state: \.transferSheet, action: /CompendiumIndexAction.transferSheet)
        )
    }
}

extension CompendiumIndexState.RS {
    static let initial = CompendiumIndexState.RS(wrapped: MapState(input: CompendiumIndexState.Query(text: nil, filters: nil, order: .title), result: .init()))

    static func initial(types: [CompendiumItemType]) -> CompendiumIndexState.RS {
        CompendiumIndexState.RS(wrapped: MapState(input: CompendiumIndexState.Query(text: nil, filters: CompendiumFilters(types: types), order: .title), result: .init()))
    }

    static func initial(type: CompendiumItemType) -> CompendiumIndexState.RS {
        initial(types: [type])
    }
}

extension CompendiumIndexState: NavigationStackItemState {
    var navigationStackItemStateId: String {
        title
    }

    var navigationTitle: String { title }
}

enum CompendiumIndexAction: NavigationStackSourceAction, Equatable {

    typealias ResultsAction = MapAction<CompendiumIndexState.Query, CompendiumIndexQueryAction, PagingData<CompendiumEntry>, PagingDataAction<CompendiumEntry>>

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

    case setNextScreen(CompendiumIndexState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(CompendiumIndexState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    indirect case alert(AlertState<CompendiumIndexAction>?)

    case setSheet(CompendiumIndexState.Sheet?)
    case creatureEditSheet(CreatureEditViewAction)
    case groupEditSheet(CompendiumItemGroupEditFeature.Action)
    case compendiumImportSheet(CompendiumImportFeature.Action)
    case documentsSheet(CompendiumDocumentsFeature.Action)
    case transferSheet(CompendiumItemTransferFeature.Action)

    static func presentScreen(_ destination: NavigationDestination, _ screen: CompendiumIndexState.NextScreen?) -> Self {
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
        case compendiumIndex(CompendiumIndexAction)
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

    static func query(_ a: CompendiumIndexQueryAction) -> CompendiumIndexAction {
        return .results(.input(a))
    }
}

enum CompendiumIndexQueryAction: Equatable {
    case onTextDidChange(String?)
    case onTypeFilterDidChange([CompendiumItemType]?)
    case onFiltersDidChange(CompendiumFilters)
}

extension CompendiumIndexState.Query {
    fileprivate static var reducer: AnyReducer<Self, CompendiumIndexQueryAction, Void> {
        return AnyReducer { state, action, _ in
            switch action {
            case .onTextDidChange(let t):
                state.text = t
            case .onTypeFilterDidChange(let types):
                if state.filters != nil {
                    state.filters?.types = types
                } else if types != nil {
                    state.filters = CompendiumFilters(types: types)
                }
                state.order = .default(types ?? CompendiumItemType.allCases)
            case .onFiltersDidChange(let f):
                if state.filters?.types != f.types {
                    state.order = .default(f.types ?? CompendiumItemType.allCases)
                }
                state.filters = f
            }
            return .none
        }
    }

    static let nullInstance = CompendiumIndexState.Query(text: nil, filters: nil, order: .title)
}

extension CompendiumIndexState {
    static let nullInstance = CompendiumIndexState(
        title: "",
        properties: Properties(showImport: false, showAdd: false),
        results: .initial,
        presentedScreens: [:]
    )
}

extension CompendiumIndexState {
    struct LastResult: Equatable {
        var input: CompendiumIndexState.Query
        var entries: [CompendiumEntry]
    }
}

extension CompendiumIndexState.RS {
    var entries: [CompendiumEntry]? {
        wrapped.result.elements ?? retained?.entries
    }

    /// Returns the input beloning to the Success value returned from `value` (which might be outdated compared
    /// to the current value for `input`.
    var inputForEntries: CompendiumIndexState.Query? {
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
