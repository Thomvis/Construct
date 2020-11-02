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

struct CompendiumIndexState: NavigationStackSourceState, Equatable {

    typealias RS = ResultSet<Query, [CompendiumEntry], Error>

    let title: String
    let properties: Properties

    var results: RS
    var scrollTo: String? // the key of the entry to scroll to

    var presentedScreens: [NavigationDestination: NextScreen]
    var alert: AlertState<CompendiumIndexAction>?

    init(title: String, properties: CompendiumIndexState.Properties, results: CompendiumIndexState.RS, presentedScreens: [NavigationDestination: NextScreen] = [:]) {
        self.title = title
        self.properties = properties
        self.results = results
        self.presentedScreens = presentedScreens
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

    var normalizedForDeduplication: Self {
        var res = self
        res.results.input = Query.nullInstance
        res.results.lastResult?.input = Query.nullInstance

        res.presentedScreens = presentedScreens.mapValues {
            switch $0 {
            case .compendiumIndex: return .compendiumIndex(CompendiumIndexState.nullInstance)
            case .groupEdit: return .groupEdit(CompendiumItemGroupEditState.nullInstance)
            case .itemDetail: return .itemDetail(CompendiumEntryDetailViewState.nullInstance)
            case .creatureEdit: return .creatureEdit(CreatureEditViewState.nullInstance)
            case .compendiumImport: return .compendiumImport(CompendiumImportViewState())
            }
        }

        return res
    }

    struct Properties: Equatable {
        let showImport: Bool
        let showAdd: Bool
        @EqIgnore var initialContent: ContentDefinition

        static let index = Properties(
            showImport: true,
            showAdd: true,
            initialContent: .initial
        )

        static let secondary = Properties(
            showImport: false,
            showAdd: true,
            initialContent: .searchResults
        )

        enum ContentDefinition {
            case fixed((Environment, CompendiumIndexView) -> AnyView)
            case searchResults

            func view(_ env: Environment, _ parent: CompendiumIndexView) -> AnyView? {
                switch self {
                case .fixed(let v): return v(env, parent)
                case .searchResults: return nil
                }
            }

            var isSearchResults: Bool {
                if case .searchResults = self { return true }
                return false
            }

            static var initial: ContentDefinition {
                initial(types: CompendiumItemType.allCases)
            }

            static func initial(types: [CompendiumItemType], destinationProperties: Properties = .secondary) -> ContentDefinition {
                ContentDefinition.fixed({ env, parent in
                    List {
                        Section {
                            if types.contains(.monster) {
                                StateDrivenNavigationLink(
                                    store: parent.store,
                                    state: /CompendiumIndexState.NextScreen.compendiumIndex,
                                    action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                                    isActive: { $0.title == "Monsters" }, // not great
                                    initialState: CompendiumIndexState(title: "Monsters", properties: destinationProperties, results: .initial(type: .monster)),
                                    destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                                ) {
                                    Text("Monsters").font(.headline).padding([.top, .bottom], 8)
                                }
                            }

                            if types.contains(.character) {
                                StateDrivenNavigationLink(
                                    store: parent.store,
                                    state: /CompendiumIndexState.NextScreen.compendiumIndex,
                                    action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                                    isActive: { $0.title == "Characters" }, // not great
                                    initialState: CompendiumIndexState(title: "Characters", properties: destinationProperties, results: .initial(type: .character)),
                                    destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                                ) {
                                    Text("Characters").font(.headline).padding([.top, .bottom], 8)
                                }
                            }

                            if types.contains(.group) {
                                StateDrivenNavigationLink(
                                    store: parent.store,
                                    state: /CompendiumIndexState.NextScreen.compendiumIndex,
                                    action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                                    isActive: { $0.title == "Adventuring Parties" }, // not great
                                    initialState: CompendiumIndexState(title: "Adventuring Parties", properties: destinationProperties, results: .initial(type: .group)),
                                    destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                                ) {
                                    Text("Adventuring Parties").font(.headline).padding([.top, .bottom], 8)
                                }
                            }

                            if types.contains(.spell) {
                                StateDrivenNavigationLink(
                                    store: parent.store,
                                    state: /CompendiumIndexState.NextScreen.compendiumIndex,
                                    action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                                    isActive: { $0.title == "Spells" }, // not great
                                    initialState: CompendiumIndexState(title: "Spells", properties: destinationProperties, results: .initial(type: .spell)),
                                    destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                                ) {
                                    Text("Spells").font(.headline).padding([.top, .bottom], 8)
                                }
                            }
                        }
                    }
                    // BUG: explicitly specify the listStyle or else it will pick side-bar style
                    .listStyle(PlainListStyle())
                    .eraseToAnyView
                })
            }
        }
    }

    enum NextScreen: Equatable {
        indirect case compendiumIndex(CompendiumIndexState)
        case groupEdit(CompendiumItemGroupEditState)
        case itemDetail(CompendiumEntryDetailViewState)
        case creatureEdit(CreatureEditViewState)
        case compendiumImport(CompendiumImportViewState)
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
                        state.nextScreen = .creatureEdit(CreatureEditViewState(create: type))
                    } else if state.results.input.filters?.types?.single == .group {
                        state.nextScreen = .groupEdit(CompendiumItemGroupEditState(mode: .create, group: CompendiumItemGroup(id: UUID(), title: "", members: [])))
                    }
                case .setNextScreen(let n):
                    state.presentedScreens[.nextInStack] = n
                case .setDetailScreen(let s):
                    state.presentedScreens[.detail] = s
                case .nextScreen(.creatureEdit(CreatureEditViewAction.onAddTap(let editState))):
                    return Effect.run { subscriber in
                        if let item = editState.compendiumItem {
                            let entry = CompendiumEntry(item)
                            _ = try? env.compendium.put(entry)
                            subscriber.send(.scrollTo(entry.key))
                        }
                        subscriber.send(.results(.reload))
                        subscriber.send(.setNextScreen(nil))
                        subscriber.send(completion: .finished)
                        return AnyCancellable { }
                    }
                case .nextScreen(.itemGroupEdit(CompendiumItemGroupEditAction.onAddTap(let group))):
                    return Effect.run { subscriber in
                        let entry = CompendiumEntry(group)
                        try? env.compendium.put(entry)

                        subscriber.send(.results(.reload))
                        subscriber.send(.scrollTo(entry.key))
                        subscriber.send(.setNextScreen(nil))
                        subscriber.send(completion: .finished)

                        return AnyCancellable { }
                    }
                case .nextScreen(.compendiumEntry(.nextScreen(.groupEdit(.onRemoveTap)))):
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
                case .nextScreen(.compendiumEntry(.nextScreen(.creatureEdit(.onRemoveTap)))):
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
                case .nextScreen, .detailScreen:
                    break
                case .alert(let s):
                    state.alert = s
                }
                return .none
            },
            Reducer.withState({ $0.properties.initialContent.isSearchResults }) { state in
                RS.reducer(CompendiumIndexState.Query.reducer) { query in
                    guard state.properties.initialContent.isSearchResults || (query.text?.nonEmptyString != nil || query.filters?.test != nil) else {
                        return nil // show initial content
                    }

                    return { env in
                        return env.compendium.fetchAll(query: query.text?.nonEmptyString, types: query.filters?.types)
                            .map { entries in
                                var result = entries
                                // filter
                                if let filterTest = query.filters?.test {
                                    result = result.filter { filterTest($0.item) }
                                }

                                // sort
                                if let order = query.order {
                                    result = result.sorted(by: SortDescriptor { order.descriptor.compare($0.item, $1.item) })
                                }

                                return result
                            }
                            .eraseToAnyPublisher()
                    }
                }.pullback(state: \.results, action: /CompendiumIndexAction.results, environment: { $0 })
            },
            Reducer.lazy(CompendiumIndexState.reducer).optional().pullback(state: \.presentedNextCompendiumIndex, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.compendiumIndex),
            CreatureEditViewState.reducer.optional().pullback(state: \.presentedNextCreatureEdit, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.creatureEdit),
            CompendiumItemGroupEditState.reducer.optional().pullback(state: \.presentedNextGroupEdit, action: /CompendiumIndexAction.nextScreen..CompendiumIndexAction.NextScreenAction.itemGroupEdit)
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

    case setNextScreen(CompendiumIndexState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(CompendiumIndexState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    indirect case alert(AlertState<CompendiumIndexAction>?)

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
        case creatureEdit(CreatureEditViewAction)
        case compendiumEntry(CompendiumItemDetailViewAction)
        case itemGroupEdit(CompendiumItemGroupEditAction)
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
    case onFiltersDidChange(CompendiumIndexState.Query.Filters)
}

extension CompendiumIndexState.Query {
    fileprivate static var reducer: Reducer<Self, CompendiumIndexQueryAction, Environment> {
        return Reducer { state, action, _ in
            switch action {
            case .onTextDidChange(let t):
                state.text = t
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
