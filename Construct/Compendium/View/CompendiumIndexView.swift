//
//  CompendiumIndexView.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CompendiumIndexView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    let store: Store<CompendiumIndexState, CompendiumIndexAction>
    @ObservedObject var localViewStore: ViewStore<LocalState, CompendiumIndexAction>

    let viewProvider: ViewProvider

    @State var didFocusOnSearch = false

    init(store: Store<CompendiumIndexState, CompendiumIndexAction>, viewProvider: ViewProvider = .default) {
        self.store = store
        self.localViewStore = ViewStore(store.scope(state: { LocalState($0) }))
        self.viewProvider = viewProvider
    }

    var body: some View {
        return VStack {
            WithViewStore(store.scope(state: { $0.results.input })) { viewStore in
                BorderedSearchField(
                    text: viewStore.binding(get: { $0.text.nonNilString }, send: { .query(.onTextDidChange($0), debounce: true) }),
                    accessory: Self.filterButton(viewStore)
                )
            }
            .introspectTextField { textField in
                if !textField.isFirstResponder, localViewStore.state.initiallyFocusOnSearch, !didFocusOnSearch {
                    textField.becomeFirstResponder()
                    didFocusOnSearch = true
                }
            }
            .padding([.leading, .top, .trailing], 8)

            if localViewStore.state.resultsValueNonNil {
                CompendiumItemList(store: store, viewProvider: viewProvider)
            } else if localViewStore.state.resultsErrorNonNil {
                Text("Loading failed").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if localViewStore.state.resultsIsFirstTimeLoading {
                Text("Loading...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                IfLetStore(store.scope(state: { CompendiumTocView.LocalState($0) })) { store in
                    CompendiumTocView(parentStore: self.store, viewStore: ViewStore(store), viewProvider: viewProvider)
                }
            }

            if let type = localViewStore.state.addButtonItemType {
                HStack {
                    RoundedButton(action: {
                        self.localViewStore.send(.onAddButtonTap)
                    }) {
                        Label("Add \(type.localizedDisplayName)", systemImage: "plus.circle")
                    }
                }
                .padding([.leading, .trailing, .bottom], 8)
                .ignoresSafeArea(.keyboard, edges: .all)
            }
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            // Dismiss the keyboard when the user starts scrolling in the list
            env.dismissKeyboard()
        })
        .navigationBarTitle(localViewStore.state.title)
        .navigationBarItems(trailing: Group {
            if localViewStore.state.showImportButton {
                Button(action: {
                    if appNavigation == .column {
                        // workaround: if we present the import screen as the next screen on iPad,
                        // the view will dismiss as soon as the document picker has opened.
                        localViewStore.send(.setDetailScreen(.compendiumImport(CompendiumImportViewState())))
                    } else {
                        localViewStore.send(.setNextScreen(.compendiumImport(CompendiumImportViewState())))
                    }
                }) {
                    Text("Import").bold()
                }
            }
        })
        .onAppear {
            loadResultsIfNeeded()
        }
        // workaround: an inline NavigationLink inside navigationBarItems would be set to inactive
        // when the document picker of the import view is dismissed
        .stateDrivenNavigationLink(
            store: store,
            state: /CompendiumIndexState.NextScreen.compendiumImport,
            action: /CompendiumIndexAction.NextScreenAction.import,
            navDest: .nextInStack,
            destination: { _ in CompendiumImportView() }
        )
        .stateDrivenNavigationLink(
            store: store,
            state: /CompendiumIndexState.NextScreen.compendiumImport,
            action: /CompendiumIndexAction.NextScreenAction.import,
            navDest: .detail,
            destination: { _ in CompendiumImportView() }
        )
        .alert(store.scope(state: \.alert), dismiss: .alert(nil))
        .sheet(item: localViewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
    }

    @ViewBuilder
    static func filterButton(_ viewStore: ViewStore<CompendiumIndexState.Query, CompendiumIndexAction>) -> some View {
        if !viewStore.state.compatibleFilterProperties.isEmpty {
            FilterButton(viewStore: viewStore)
        } else {
            EmptyView()
        }
    }

    private func loadResultsIfNeeded() {
        if localViewStore.state.initialContentIsSearchResults, !localViewStore.state.resultsValueNonNil {
            localViewStore.send(.query(.onTextDidChange(ViewStore(store).state.results.input.text), debounce: false)) // kick-start search, fixme?
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: CompendiumIndexState.Sheet) -> some View {
        IfLetStore(
            store.scope(state: replayNonNil({ $0.creatureEditSheet }), action: { .creatureEditSheet($0) }),
            then: { store in
                SheetNavigationContainer(isModalInPresentation: true) {
                    CreatureEditView(store: store)
                }
            },
            else: IfLetStore(
                store.scope(state: replayNonNil({ $0.groupEditSheet }), action: { .groupEditSheet($0) }),
                then: { store in
                    SheetNavigationContainer {
                        CompendiumItemGroupEditView(store: store)
                    }
                }
            )
        )
    }

    struct LocalState: Equatable {
        let initiallyFocusOnSearch: Bool
        let initialContentIsSearchResults: Bool

        let resultsValueNonNil: Bool
        let resultsErrorNonNil: Bool
        let resultsIsFirstTimeLoading: Bool

        let addButtonItemType: CompendiumItemType?

        let title: String
        let showImportButton: Bool

        let isShowingImport: Bool
        @EqKey({ $0?.id })
        var sheet: CompendiumIndexState.Sheet?

        init(_ state: CompendiumIndexState) {
            initiallyFocusOnSearch = state.properties.initiallyFocusOnSearch
            initialContentIsSearchResults = state.properties.initialContent.isSearchResults

            resultsValueNonNil = state.results.value != nil
            resultsErrorNonNil = state.results.error != nil
            resultsIsFirstTimeLoading = state.results.value == nil && state.results.result.isLoading

            if state.properties.showAdd && state.canAddItem {
                addButtonItemType = state.results.input.filters?.types?.single
            } else {
                addButtonItemType = nil
            }

            title = state.title
            showImportButton = state.properties.showImport

            isShowingImport = state.presentedNextCompendiumImport != nil || state.presentedDetailCompendiumImport != nil
            sheet = state.sheet
        }
    }
}

extension CompendiumIndexView {
    struct ViewProvider {
        let row: (Store<CompendiumIndexState, CompendiumIndexAction>, CompendiumEntry) -> AnyView
        let detail: (Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>) -> AnyView

        static let `default` = ViewProvider(
            row: { store, entry in
                CompendiumItemRow(store: store, item: entry.item).eraseToAnyView
            },
            detail: { store in
                CompendiumItemDetailView(store: store).eraseToAnyView
            }
        )
    }
}

fileprivate struct CompendiumTocView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    let parentStore: Store<CompendiumIndexState, CompendiumIndexAction>

    @ObservedObject var viewStore: ViewStore<LocalState, CompendiumIndexAction>
    let viewProvider: CompendiumIndexView.ViewProvider

    var body: some View {
        List {
            Section {
                ForEach(viewStore.state.toc.types, id: \.self) { type in
                    NavigationRowButton(action: {
                        let destination = CompendiumIndexState(
                            title: type.localizedScreenDisplayName,
                            properties: viewStore.state.toc.destinationProperties,
                            results: .initial(type: type)
                        )
                        viewStore.send(.setNextScreen(.compendiumIndex(destination)))
                    }) {
                        Text(type.localizedScreenDisplayName)
                            .foregroundColor(Color.primary)
                            .font(.headline)
                            .padding([.top, .bottom], 8)
                    }
                }
            }

            if !viewStore.state.toc.suggested.isEmpty {
                Section(header: Text("Suggested")) {
                    ForEach(viewStore.state.toc.suggested, id: \.key) { entry in
                        NavigationRowButton(action: {
                            if appNavigation == .tab {
                                viewStore.send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                            } else {
                                viewStore.send(.setDetailScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                            }
                        }) {
                            viewProvider.row(parentStore, entry)
                        }
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        // Workaround: we use a single NavigationLink instead of one per row because that breaks
        // programmatic navigation inside the reference view.
        // Apparently NavigationLinks inside a List work slightly differently
        .stateDrivenNavigationLink(
            store: parentStore,
            state: /CompendiumIndexState.NextScreen.compendiumIndex,
            action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
            destination: { CompendiumIndexView(store: $0, viewProvider: viewProvider) }
        )
        .stateDrivenNavigationLink(
            store: parentStore,
            state: /CompendiumIndexState.NextScreen.itemDetail,
            action: /CompendiumIndexAction.NextScreenAction.compendiumEntry,
            navDest: appNavigation == .tab ? .nextInStack : .detail,
            destination: { viewProvider.detail($0) }
        )
    }

    struct LocalState: Equatable {
        let toc: CompendiumIndexState.Properties.ContentDefinition.Toc
        // not used by the view (store is used directly) but here to ensure the view is re-evaluated
        let presentedCompendiumIndex: String?
        let presentedItemDetail: String?

        init?(_ state: CompendiumIndexState) {
            guard let toc = state.properties.initialContent.toc else { return nil }

            self.toc = toc
            self.presentedCompendiumIndex = state.presentedNextCompendiumIndex?.navigationStackItemStateId
                ?? state.presentedDetailCompendiumIndex?.navigationStackItemStateId

            self.presentedItemDetail = state.presentedNextItemDetail?.navigationStackItemStateId
                ?? state.presentedDetailItemDetail?.navigationStackItemStateId
        }
    }
}

fileprivate struct CompendiumItemList: View {
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    var store: Store<CompendiumIndexState, CompendiumIndexAction>
    @ObservedObject var viewStore: ViewStore<LocalState, CompendiumIndexAction>

    let viewProvider: CompendiumIndexView.ViewProvider

    init(store: Store<CompendiumIndexState, CompendiumIndexAction>, viewProvider: CompendiumIndexView.ViewProvider) {
        self.store = store
        self.viewStore = ViewStore(store.scope(state: { LocalState($0) }))
        self.viewProvider = viewProvider
    }

    var body: some View {
        let listHash = AnyHashable(viewStore.state.entries.map { $0.key })
        return ScrollViewReader { scrollView in
            List {
                if viewStore.state.entries.isEmpty {
                    Text("No results")
                }

                ForEach(viewStore.state.entries, id: \.key) { entry in
                    NavigationRowButton(action: {
                        if appNavigation == .tab {
                            self.viewStore.send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                        } else {
                            self.viewStore.send(.setDetailScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                        }
                    }) {
                        self.viewProvider.row(self.store, entry)
                    }
                }
            }
            // Workaround: without the id, the ForEach above would sometimes not be re-evaluated
            // (e.g. when switching between compendium types)
            // At the moment of writing, the sidebar navigation link to the compendium is made in a way
            // that a switch from one compendium type to another does not create a new CompendiumIndexView
            // instance
            .id(viewStore.state.title)
            // Workaround: we use a single NavigationLink instead of one per row because that breaks
            // programmatic navigation inside the reference view
            .stateDrivenNavigationLink(
                store: store,
                state: /CompendiumIndexState.NextScreen.itemDetail,
                action: /CompendiumIndexAction.NextScreenAction.compendiumEntry,
                navDest: appNavigation == .tab ? .nextInStack : .detail,
                destination: { viewProvider.detail($0) }
            )
            .onChange(of: [listHash, AnyHashable(viewStore.state.scrollTo)]) { _ in
                // workaround: this closure is called with `self.entries` still out of date,
                // that's why we access it from viewStore
                let entries = viewStore.state.entries
                if let id = viewStore.state.scrollTo, entries.contains(where: { $0.key == id }) {
                    withAnimation {
                        scrollView.scrollTo(id)
                    }
                    viewStore.send(.scrollTo(nil))
                }
            }
        }
    }

    struct LocalState: Equatable {
        let title: String
        let entries: [CompendiumEntry]
        // not used by the view (store is used directly) but here to ensure the view is re-evaluated
        let presentedItemDetail: String?

        let scrollTo: String?

        init(_ state: CompendiumIndexState) {
            self.title = state.title
            self.entries = state.results.value ?? []
            self.presentedItemDetail = state.presentedNextItemDetail?.navigationStackItemStateId
                ?? state.presentedDetailItemDetail?.navigationStackItemStateId

            self.scrollTo = state.scrollTo
        }
    }
}

fileprivate struct CompendiumItemRow: View {
    @EnvironmentObject var env: Environment

    fileprivate var store: Store<CompendiumIndexState, CompendiumIndexAction>

    let item: CompendiumItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title)
            item.localizedSummary(in: ViewStore(store).state, env: env).font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

struct FilterButton: View {
    @EnvironmentObject var env: Environment

    @ObservedObject var viewStore: ViewStore<CompendiumIndexState.Query, CompendiumIndexAction>

    @State var popover: Popover?

    var body: some View {
        SimpleButton(action: {
            let state = CompendiumFilterPopoverState(self.viewStore.state.filters, self.viewStore.state.compatibleFilterProperties)

            self.popover = CompendiumFilterPopover(store: Store(initialState: state, reducer: CompendiumFilterPopoverState.reducer, environment: self.env)) { filterValues in
                var filters = self.viewStore.state.filters ?? CompendiumIndexState.Query.Filters(types: nil)
                filters.minMonsterChallengeRating = filterValues.minMonsterCR
                filters.maxMonsterChallengeRating = filterValues.maxMonsterCR
                self.viewStore.send(.query(.onFiltersDidChange(filters), debounce: false))
                self.popover = nil
            }
        }) {
            Image(systemName: "slider.horizontal.3")
                .font(Font.body.weight(filtersAreActive ? .bold : .regular))
                .foregroundColor(filtersAreActive ? Color(UIColor.systemBlue) : Color(UIColor.label))
        }
        .popover($popover)
    }

    var filtersAreActive: Bool {
        viewStore.state.filters?.test != nil
    }
}

extension CompendiumItem {
    func localizedSummary(in context: CompendiumIndexState, env: Environment) -> Text? {
        let isTypeConstrained = context.results.input.filters?.types?.single != nil

        var components: [Text] = []
        switch self {
        case let m as Monster:
            if !isTypeConstrained {
                components.append(Text("Monster"))
            }
            components.append(Text(m.localizedStatsSummary))
        case let c as Character:
            if let level = c.level {
                if let type = c.stats.type {
                    components.append(Text("Level \(level) \(type)"))
                } else {
                    components.append(Text("Level \(level)"))
                }
            }

            if let player = c.player {
                if let name = player.name {
                    components.append(Text("Played by \(name)"))
                } else {
                    components.append(Text("Player character"))
                }
            } else {
                components.append(Text("NPC"))
            }
        case let s as Spell:
            if let level = s.level {
                var text = "\(env.ordinalFormatter.stringWithFallback(for: level)) level"
                if !isTypeConstrained {
                    text = "Spell, \(text)"
                }
                components.append(Text(text))
            } else {
                if isTypeConstrained {
                    components.append(Text("Cantrip"))
                } else {
                    components.append(Text("Spell, cantrip"))
                }
            }
            components.append(Text(s.castingTime.truncated(20)))
            components.append(Text(s.duration))
            components.append(Text(s.range))
        case let g as CompendiumItemGroup:
            if let nameList = ListFormatter().string(from: g.members.map { $0.itemTitle }) {
                if isTypeConstrained {
                    components.append(Text(nameList))
                } else {
                    components.append(Text("Party of \(nameList)"))
                }
            } else if !isTypeConstrained {
                components.append(Text("Party"))
            }
        default: return nil
        }

        // join
        if var result = components.first {
            for c in components.dropFirst() {
                result = result + Text(" | " ) + c
            }
            return result
        }
        return nil
    }
}

extension CompendiumItemType {
    var defaultOrder: CompendiumIndexState.Query.Order? {
        switch self {
        case .monster: return .monsterChallengeRating
        case .character: return nil
        case .spell: return .spellLevel
        case .group: return nil
        }
    }
}

// Used for communicating with the filter popover
fileprivate extension CompendiumFilterPopoverState {
    init(_ queryFilters: CompendiumIndexState.Query.Filters?, _ filters: [Filter]) {
        self.filters = filters

        let values = Values(
            minMonsterCR: queryFilters?.minMonsterChallengeRating,
            maxMonsterCR: queryFilters?.maxMonsterChallengeRating
        )
        self.initial = values
        self.current = values
    }
}
