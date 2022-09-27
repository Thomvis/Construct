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

struct CompendiumIndexState: NavigationStackSourceState, Equatable {

    typealias RS = ResultSet<Query, [CompendiumEntry], Error>

    let title: String
    var properties: Properties

    var results: RS
    var scrollTo: String? // the key of the entry to scroll to

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

    var canAddItem: Bool {
        editViewCreatureType != nil || canCreateNewEmptyItem
    }

    var editViewCreatureType: CreatureEditViewState.CreatureType? {
        results.input.filters?.types?.single?.creatureType
    }

    var canCreateNewEmptyItem: Bool {
        guard let type = results.input.filters?.types?.single else { return false }
        return type == .group
    }

    var localStateForDeduplication: Self {
        var res = self
        res.results.input = Query.nullInstance
        res.results.lastResult?.input = Query.nullInstance

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
        let initiallyFocusOnSearch: Bool
        @EqIgnore var initialContent: ContentDefinition

        static let index = Properties(
            showImport: true,
            showAdd: true,
            initiallyFocusOnSearch: false,
            initialContent: .initial
        )

        static let secondary = Properties(
            showImport: false,
            showAdd: true,
            initiallyFocusOnSearch: false,
            initialContent: .searchResults
        )

        enum ContentDefinition {
            indirect case toc(Toc)
            case searchResults

            func view(_ env: Environment, _ parent: CompendiumIndexView) -> AnyView? {
                switch self {
                case .toc: return nil
                case .searchResults: return nil
                }
            }

            var isSearchResults: Bool {
                if case .searchResults = self { return true }
                return false
            }

            var toc: Toc? {
                guard case .toc(let toc) = self else { return nil }
                return toc
            }

            static var initial: ContentDefinition {
                initial(types: CompendiumItemType.allCases)
            }

            static func initial(types: [CompendiumItemType], destinationProperties: Properties = .secondary) -> ContentDefinition {
                .toc(Toc(types: types, destinationProperties: destinationProperties, suggested: []))
            }

            struct Toc: Equatable {
                var types: [CompendiumItemType]
                var destinationProperties: Properties
                var suggested: [CompendiumEntry]
            }
        }
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

    static var reducer: Reducer<Self, CompendiumIndexAction, Environment> {
        return Reducer.combine(
            CompendiumEntryDetailViewState.reducer.optional().pullback(state: \.presentedNextItemDetail, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry),
            CompendiumEntryDetailViewState.reducer.optional().pullback(state: \.presentedDetailItemDetail, action: /CompendiumIndexAction.detailScreen..CompendiumIndexAction.NextScreenAction.compendiumEntry),
            Reducer { state, action, env in
                switch action {
                case .results: break
                case .scrollTo(let id):
                    state.scrollTo = id
                case .onAddButtonTap:
                    if let type = state.editViewCreatureType {
                        state.sheet = .creatureEdit(CreatureEditViewState(create: type))
                    } else if state.results.input.filters?.types?.single == .group {
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
                    return Effect.run { subscriber in
                        if let item = editState.compendiumItem {
                            let entry = CompendiumEntry(item)
                            _ = try? env.compendium.put(entry)
                            subscriber.send(.scrollTo(entry.key))
                        }
                        subscriber.send(.results(.reload))
                        subscriber.send(.setSheet(nil))
                        subscriber.send(completion: .finished)
                        return AnyCancellable { }
                    }
                case .groupEditSheet(CompendiumItemGroupEditAction.onAddTap(let group)):
                    return Effect.run { subscriber in
                        let entry = CompendiumEntry(group)
                        try? env.compendium.put(entry)

                        subscriber.send(.results(.reload))
                        subscriber.send(.scrollTo(entry.key))
                        subscriber.send(.setSheet(nil))
                        subscriber.send(completion: .finished)

                        return AnyCancellable { }
                    }
                case .nextScreen(.compendiumEntry(.didRemoveItem)),
                     .detailScreen(.compendiumEntry(.didRemoveItem)):
                    return Effect.run { subscriber in
                        subscriber.send(.setNextScreen(nil))

                        // Work-around: without the delay, `.setNextScreen(nil)` is not picked up
                        // (probably because .reload makes the NavigationLink disappear)
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                            subscriber.send(.results(.reload))
                            subscriber.send(completion: .finished)
                        }

                        return AnyCancellable { }
                    }
                case .nextScreen(.compendiumEntry(.sheet(.creatureEdit(.onDoneTap)))),
                     .detailScreen(.compendiumEntry(.sheet(.creatureEdit(.onDoneTap)))):
                    return Effect(value: .results(.reload))
                case .nextScreen(.compendiumEntry(.entry)),
                     .detailScreen(.compendiumEntry(.entry)):
                    return Effect(value: .results(.reload))
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
            Reducer.withState({ $0.properties.initialContent.isSearchResults }) { state in
                RS.reducer(CompendiumIndexState.Query.reducer) { query in
                    guard state.properties.initialContent.isSearchResults || (query.text?.nonEmptyString != nil || query.filters?.test != nil) else {
                        return nil // show initial content
                    }

                    return { env in
                        return Deferred(catching: { () -> [CompendiumEntry] in
                            do {
                                return try env.compendium.fetchAll(query: query.text?.nonEmptyString, types: query.filters?.types)
                            } catch {
                                env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [:]))
                                throw error
                            }
                        }).map { entries in
                            var result = entries
                            // filter
                            if let filterTest = query.filters?.test {
                                result = result.filter { filterTest($0.item) }
                            }

                            // sort
                            if let order = query.order {
                                result = result.sorted(by: order.descriptor.pullback(\.item))
                            }

                            return result
                        }.eraseToAnyPublisher()
                    }
                }.pullback(state: \.results, action: /CompendiumIndexAction.results, environment: { $0 })
            },
            Reducer.lazy(CompendiumIndexState.reducer).optional().pullback(state: \.presentedNextCompendiumIndex, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumIndex),
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditSheet, action: /CompendiumIndexAction.creatureEditSheet),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.groupEditSheet, action: /CompendiumIndexAction.groupEditSheet)
        )
    }
}

extension CompendiumIndexState.RS {
    static let initial = CompendiumIndexState.RS(input: CompendiumIndexState.Query(text: nil, filters: nil))

    static func initial(types: [CompendiumItemType]) -> CompendiumIndexState.RS {
        CompendiumIndexState.RS(input: CompendiumIndexState.Query(text: nil, filters: CompendiumIndexState.Query.Filters(types: types), order: types.single?.defaultOrder))
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

    case results(CompendiumIndexState.RS.Action<CompendiumIndexQueryAction>)
    case scrollTo(String?)
    case onAddButtonTap
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
    var results: CompendiumIndexState.RS.Action<CompendiumIndexQueryAction>? {
        get {
            guard case .results(let a) = self else { return nil }
            return a
        }
        set {
            guard case .results = self, let value = newValue else { return }
            self = .results(value)
        }
    }

    static func query(_ a: CompendiumIndexQueryAction, debounce: Bool) -> CompendiumIndexAction {
        return .results(.input(a, debounce: debounce))
    }
}

enum CompendiumIndexQueryAction: Equatable {
    case onTextDidChange(String?)
    case onTypeFilterDidChange([CompendiumItemType]?)
    case onFiltersDidChange(CompendiumIndexState.Query.Filters)
}

extension CompendiumIndexState.Query {
    fileprivate static var reducer: Reducer<Self, CompendiumIndexQueryAction, Environment> {
        return Reducer { state, action, _ in
            switch action {
            case .onTextDidChange(let t):
                state.text = t
            case .onTypeFilterDidChange(let types):
                if state.filters != nil {
                    state.filters?.types = types
                } else {
                    state.filters = Filters(types: types)
                }
            case .onFiltersDidChange(let f):
                state.filters = f
            }
            return .none
        }
    }

    static let nullInstance = CompendiumIndexState.Query(text: nil, filters: nil, order: nil)
}

extension CompendiumIndexState {
    static let nullInstance = CompendiumIndexState(
        title: "",
        properties: Properties.index,
        results: .initial,
        presentedScreens: [:]
    )
}
