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

struct CompendiumIndexState: NavigationStackSourceState, Equatable {

    typealias MS = MapState<Query, PagingData<CompendiumEntry>>
    typealias RS = RetainState<MS, LastResult>

    let title: String
    var properties: Properties

    var results: RS
    var suggestions: [CompendiumEntry]?
    
    var scrollTo: CompendiumEntry.Key? // the key of the entry to scroll to

    var presentedScreens: [NavigationDestination: NextScreen]
    var alert: AlertState<CompendiumIndexAction>?
    var sheet: Sheet?

    init(title: String, properties: CompendiumIndexState.Properties, results: CompendiumIndexState.RS, presentedScreens: [NavigationDestination: NextScreen] = [:], sheet: Sheet? = nil) {
        self.title = title
        self.properties = properties
        self.results = results
        self.presentedScreens = presentedScreens
        self.sheet = sheet
    }

    var localStateForDeduplication: Self {
        var res = self
        res.results.input = Query.nullInstance
        res.results.retained?.input = Query.nullInstance

        res.presentedScreens = presentedScreens.mapValues {
            switch $0 {
            case .compendiumIndex: return .compendiumIndex(CompendiumIndexState.nullInstance)
            case .itemDetail: return .itemDetail(CompendiumEntryDetailViewState.nullInstance)
            case .compendiumImport: return .compendiumImport(CompendiumImportViewState())
            case .safariView: return .safariView(.nullInstance)
            }
        }
        res.sheet = sheet.map {
            switch $0 {
            case .creatureEdit: return .creatureEdit(CreatureEditViewState.nullInstance)
            case .groupEdit: return .groupEdit(CompendiumItemGroupEditState.nullInstance)
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

    var groupEditSheet: CompendiumItemGroupEditState? {
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

    struct Properties: Equatable {
        let showImport: Bool
        let showAdd: Bool
        let typeRestriction: [CompendiumItemType]?
    }

    enum NextScreen: Equatable {
        indirect case compendiumIndex(CompendiumIndexState)
        case itemDetail(CompendiumEntryDetailViewState)
        case compendiumImport(CompendiumImportViewState)
        case safariView(SafariViewState)
    }

    enum Sheet: Equatable, Identifiable {
        // creatureEdit and groupEdit are used when adding a new creature/group
        case creatureEdit(CreatureEditViewState)
        case groupEdit(CompendiumItemGroupEditState)

        var id: String {
            switch self {
            case .creatureEdit(let s): return s.navigationStackItemStateId
            case .groupEdit(let s): return s.navigationStackItemStateId
            }
        }
    }

    static var reducer: AnyReducer<Self, CompendiumIndexAction, Environment> {
        return AnyReducer.combine(
            CompendiumEntryDetailViewState.reducer.optional().pullback(state: \.presentedNextItemDetail, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry),
            CompendiumEntryDetailViewState.reducer.optional().pullback(state: \.presentedDetailItemDetail, action: /CompendiumIndexAction.detailScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry),
            AnyReducer { state, action, env in
                switch action {
                case .results: break
                case .scrollTo(let id):
                    state.scrollTo = id
                case .onQueryTypeFilterDidChange(let typeFilter):
                    if typeFilter == nil && state.properties.typeRestriction == nil {
                        return Effect(value: .query(.onTypeFilterDidChange(nil)))
                    } else {
                        let restrictions = state.properties.typeRestriction ?? CompendiumItemType.allCases
                        let new = typeFilter ?? CompendiumItemType.allCases
                        let withinRestrictions = new.filter { restrictions.contains($0 )}
                        return Effect(value: .query(.onTypeFilterDidChange(withinRestrictions)))
                    }
                case .onAddButtonTap(let type):
                    switch type {
                    case .monster, .character:
                        guard let creatureType = type.creatureType else {
                            assertionFailure("Adding item of type \(type) is not supported yet")
                            break
                        }
                        state.sheet = .creatureEdit(CreatureEditViewState(create: creatureType))
                    case .spell:
                        assertionFailure("Adding spells is not supported")
                        break
                    case .group:
                        state.sheet = .groupEdit(CompendiumItemGroupEditState(mode: .create, group: CompendiumItemGroup(id: UUID().tagged(), title: "", members: [])))
                    }

                case .onSearchOnWebButtonTap:
                    let externalCompendium = DndBeyondExternalCompendium()
                    state.presentedNextSafariView = SafariViewState(
                        url: externalCompendium.searchPageUrl(
                            for: state.results.input.text ?? "",
                            types: state.results.input.filters?.types
                        )
                    )
                case .setNextScreen(let n):
                    state.presentedScreens[.nextInStack] = n
                case .setDetailScreen(let s):
                    state.presentedScreens[.detail] = s
                case .creatureEditSheet(CreatureEditViewAction.onAddTap(let editState)):
                    // adding a new creature
                    return Effect.run { subscriber in
                        if let item = editState.compendiumItem {
                            let entry = CompendiumEntry(item)
                            _ = try? env.compendium.put(entry)
                            subscriber.send(.scrollTo(entry.key))
                            subscriber.send(.results(.result(.reload(.all))))
                        }
                        subscriber.send(.setSheet(nil))
                        subscriber.send(completion: .finished)
                        return AnyCancellable { }
                    }
                case .groupEditSheet(CompendiumItemGroupEditAction.onAddTap(let group)):
                    // adding a group
                    return Effect.run { subscriber in
                        let entry = CompendiumEntry(group)
                        try? env.compendium.put(entry)

                        subscriber.send(.results(.result(.reload(.all))))
                        subscriber.send(.scrollTo(entry.key))
                        subscriber.send(.setSheet(nil))
                        subscriber.send(completion: .finished)

                        return AnyCancellable { }
                    }
                case .nextScreen(.compendiumEntry(.didRemoveItem)),
                     .detailScreen(.compendiumEntry(.didRemoveItem)):
                    // creature removed
                    return Effect.run { subscriber in
                        subscriber.send(.setNextScreen(nil))

                        // Work-around: without the delay, `.setNextScreen(nil)` is not picked up
                        // (probably because .reload makes the NavigationLink disappear)
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                            subscriber.send(.results(.result(.reload(.currentCount))))
                            subscriber.send(completion: .finished)
                        }

                        return AnyCancellable { }
                    }
                case .nextScreen(.compendiumEntry(.sheet(.creatureEdit(.onDoneTap)))),
                     .detailScreen(.compendiumEntry(.sheet(.creatureEdit(.onDoneTap)))):
                    // done editing an existing creature
                    return Effect(value: .results(.result(.reload(.currentCount))))
                case .nextScreen(.compendiumEntry(.entry)),
                     .detailScreen(.compendiumEntry(.entry)):
                    // creature on the detail screen changed
                    return Effect(value: .results(.result(.reload(.currentCount))))
                case .nextScreen, .detailScreen:
                    break
                case .alert(let s):
                    state.alert = s
                case .setSheet(let s):
                    state.sheet = s
                case .creatureEditSheet, .groupEditSheet: break // handled below
                }
                return .none
            },
            MS.reducer(
                inputReducer: CompendiumIndexState.Query.reducer,
                initialResultStateForInput: { _ in PagingData() },
                initialResultActionForInput: { _ in .didShowElementAtIndex(0) },
                resultReducerForInput: { query in
                    PagingData.reducer { request, env in
                        let entries: [CompendiumEntry]
                        do {
                            entries = try env.compendium.fetchAll(
                                search: query.text?.nonEmptyString,
                                filters: query.filters,
                                order: query.order,
                                range: request.range
                            )
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
            .pullback(state: \.results, action: /CompendiumIndexAction.results),
            AnyReducer.lazy(CompendiumIndexState.reducer).optional().pullback(state: \.presentedNextCompendiumIndex, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumIndex),
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumIndexAction.creatureEditSheet, environment: { $0 }),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.groupEditSheet, action: /CompendiumIndexAction.groupEditSheet)
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

    typealias ResultsAction = MapAction<CompendiumIndexQueryAction, PagingDataAction<CompendiumEntry>>

    case results(ResultsAction)
    case scrollTo(CompendiumEntry.Key?)
    case onQueryTypeFilterDidChange([CompendiumItemType]?)
    case onAddButtonTap(CompendiumItemType)
    case onSearchOnWebButtonTap

    case setNextScreen(CompendiumIndexState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(CompendiumIndexState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    indirect case alert(AlertState<CompendiumIndexAction>?)

    case setSheet(CompendiumIndexState.Sheet?)
    case creatureEditSheet(CreatureEditViewAction)
    case groupEditSheet(CompendiumItemGroupEditAction)

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
        case compendiumEntry(CompendiumItemDetailViewAction)
        case `import`
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
    fileprivate static var reducer: AnyReducer<Self, CompendiumIndexQueryAction, Environment> {
        return AnyReducer { state, action, _ in
            switch action {
            case .onTextDidChange(let t):
                state.text = t
            case .onTypeFilterDidChange(let types):
                if state.filters != nil {
                    state.filters?.types = types
                } else {
                    state.filters = CompendiumFilters(types: types) //todo: if state.filters is nil it should remain nil here
                }
                state.order = .default(types ?? CompendiumItemType.allCases)
            case .onFiltersDidChange(let f):
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
        properties: Properties(showImport: false, showAdd: false, typeRestriction: nil),
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
