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
import BetterSafariView
import GameModels
import Helpers
import SharedViews

struct CompendiumIndexView<BottomBarButtons>: View where BottomBarButtons: View {
    @EnvironmentObject var env: Environment

    let store: Store<CompendiumIndexState, CompendiumIndexAction>
    @ObservedObject var localViewStore: ViewStore<LocalState, CompendiumIndexAction>

    let viewProvider: CompendiumIndexViewProvider

    let bottomBarButtons: () -> BottomBarButtons

    @State var didFocusOnSearch = false

    init(
        store: Store<CompendiumIndexState, CompendiumIndexAction>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons
    ) {
        self.store = store
        self.localViewStore = ViewStore(store.scope(state: { LocalState($0) }))
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    init(
        store: Store<CompendiumIndexState, CompendiumIndexAction>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons = { EmptyView() }
    ) where BottomBarButtons == EmptyView {
        self.store = store
        self.localViewStore = ViewStore(store.scope(state: { LocalState($0) }))
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    var body: some View {
        Group {
            contentView
        }
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: localViewStore.binding(get: { $0.searchText.nonNilString }, send: { .query(.onTextDidChange($0), debounce: true) }),
            tokens: localViewStore.binding(get: { $0.itemTypeFilter ?? [] }, send: { .onQueryTypeFilterDidChange($0.nonEmptyArray, debounce: false) }),
            token: { type in
                Text(type.localizedScreenDisplayName)
            }
        )
        .searchSuggestions {
            ForEach(searchSuggestions, id: \.rawValue) { type in
                Text("\(type.localizedScreenDisplayName)").searchCompletion(type)
            }
        }
        .safeAreaInset(edge: .bottom) {
            RoundedButtonToolbar {
                bottomBarButtons()

                if localViewStore.state.showAddButton {
                    let addableTypes = localViewStore.state.addableItemTypes
                    if let type = addableTypes.single {
                        Button(action: {
                            self.localViewStore.send(.onAddButtonTap(type))
                        }) {
                            Label("Add \(type.localizedDisplayName)", systemImage: "plus.circle")
                        }
                    } else {
                        Menu {
                            Button {
                                localViewStore.send(.setNextScreen(.compendiumImport(CompendiumImportViewState())))
                            } label: {
                                Text("Import...")
                            }

                            Divider()

                            ForEach(addableTypes, id: \.rawValue) { type in
                                Button {
                                    self.localViewStore.send(.onAddButtonTap(type))
                                } label: {
                                    Text("New \(type.localizedDisplayName)")
                                }
                            }
                        } label: {
                            Button(action: {

                            }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }
                    }
                }

                WithViewStore(store.scope(state: { $0.results.input })) { viewStore in
                    FilterButton(
                        viewStore: viewStore,
                        allAllowedItemTypes: localViewStore.state.allAllowedItemTypes
                    )
                }
            }
            .padding([.leading, .trailing, .bottom], 8)
        }
        .navigationBarTitle(localViewStore.state.title, displayMode: .inline)
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
    var contentView: some View {
        switch localViewStore.state.results {
        case .succeededWithoutResults:
            WithViewStore(store.scope(state: { $0.presentedNextSafariView })) { safariViewStore in
                VStack(spacing: 18) {
                    Text("No results").font(.title)

                    Button("Search the web") {
                        localViewStore.send(.onSearchOnWebButtonTap)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safariView(
                    item: safariViewStore.binding(get: { $0 }, send: { _ in .setNextScreen(nil) }),
                    onDismiss: { localViewStore.send(.setNextScreen(nil)) },
                    content: { state in
                        BetterSafariView.SafariView(
                            url: state.url
                        )
                    }
                )
            }
        case .succeededWithResults, .loadingInitialContent:
            ZStack {
                CompendiumItemList(store: store, viewProvider: viewProvider)

                if localViewStore.state.isLoadingResults {
                    Label("Loading…", systemImage: "sparkle.magnifyingglass")
                        .padding()
                        .background(Material.regular, in: RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.animation(.default))
                }
            }
        case .failedWithError:
            Text("Loading failed").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Returns allowed item types (as per type restriction), but only if the user has not
    /// added a query or changed the type filter. If that's the case, an empty array is returned.
    var searchSuggestions: [CompendiumItemType] {
        localViewStore.state.searchText?.nonEmptyString == nil && localViewStore.state.itemTypeFilter == nil
            ? localViewStore.state.allAllowedItemTypes
            : []
    }

    private func loadResultsIfNeeded() {
        if !localViewStore.state.results.isSuccess {
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
            else: {
                IfLetStore(
                    store.scope(state: replayNonNil({ $0.groupEditSheet }), action: { .groupEditSheet($0) }),
                    then: { store in
                        SheetNavigationContainer {
                            CompendiumItemGroupEditView(store: store)
                        }
                    }
                )
            }
        )
    }

    struct LocalState: Equatable {
        let results: ResultsStatus
        let isLoadingResults: Bool

        let itemTypeRestriction: [CompendiumItemType]?
        let itemTypeFilter: [CompendiumItemType]?
        let showAddButton: Bool

        let title: String
        let showImportButton: Bool

        let isShowingImport: Bool
        @EqKey({ $0?.id })
        var sheet: CompendiumIndexState.Sheet?

        let searchText: String?

        init(_ state: CompendiumIndexState) {
            if let resValues = state.results.value {
                self.results = resValues.isEmpty ? .succeededWithoutResults : .succeededWithResults
            } else if state.results.error != nil {
                self.results = .failedWithError
            } else {
                self.results = .loadingInitialContent
            }
            self.isLoadingResults = state.results.result.isLoading == true

            itemTypeRestriction = state.properties.typeRestriction
            if Set(state.results.input.filters?.types ?? []) == Set(state.properties.typeRestriction ?? CompendiumItemType.allCases) {
                itemTypeFilter = nil
            } else {
                itemTypeFilter = state.results.input.filters?.types
            }
            showAddButton = state.properties.showAdd

            title = state.title
            showImportButton = state.properties.showImport

            isShowingImport = state.presentedNextCompendiumImport != nil || state.presentedDetailCompendiumImport != nil

            searchText = state.results.input.text

            sheet = state.sheet
        }

        var allAllowedItemTypes: [CompendiumItemType] {
            itemTypeRestriction ?? CompendiumItemType.allCases
        }

        var addableItemTypes: [CompendiumItemType] {
            return (itemTypeFilter ?? CompendiumItemType.allCases).filter { [.monster, .character, .group].contains($0) }
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
    }
}

struct CompendiumIndexViewProvider {
    let row: (Store<CompendiumIndexState, CompendiumIndexAction>, CompendiumEntry) -> AnyView
    let detail: (Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>) -> AnyView

    /// Can be used by the view to invalidate itself if the state changes
    let state: () -> any Equatable

    static let `default` = CompendiumIndexViewProvider(
        row: { store, entry in
            CompendiumItemRow(store: store, item: entry.item).eraseToAnyView
        },
        detail: { store in
            CompendiumItemDetailView(store: store).eraseToAnyView
        },
        state: { 0 }
    )
}

fileprivate struct CompendiumItemList: View, Equatable {

    var store: Store<CompendiumIndexState, CompendiumIndexAction>
    @ObservedObject var viewStore: ViewStore<LocalState, CompendiumIndexAction>

    let viewProvider: CompendiumIndexViewProvider

    init(store: Store<CompendiumIndexState, CompendiumIndexAction>, viewProvider: CompendiumIndexViewProvider) {
        self.store = store
        self.viewStore = ViewStore(store.scope(state: { LocalState($0) }))
        self.viewProvider = viewProvider
    }

    var body: some View {
        let listHash = AnyHashable((viewStore.state.entries + (viewStore.state.suggestions ?? [])).map { $0.key })

        let state = viewStore.state
        return ScrollViewReader { scrollView in
            return List {
                if let suggestions = state.suggestions {
                    section(header: Text("Suggestions"), entries: suggestions)
                    section(header: Text("All"), entries: state.entries)
                } else {
                    section(entries: state.entries)
                }
            }
            .listStyle(.plain)
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
                navDest: .nextInStack,
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

    @ViewBuilder
    func section<H>(header: H, entries: [CompendiumEntry]) -> some View where H: View  {
        Section(header: header) {
            ForEach(entries, id: \.key) { entry in
                NavigationRowButton(action: {
                    viewStore.send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                }) {
                    viewProvider.row(self.store, entry)
                }
            }
        }
    }

    func section(entries: [CompendiumEntry]) -> some View {
        section(header: EmptyView(), entries: entries)
    }

    struct LocalState: Equatable {
        let title: String
        let entries: [CompendiumEntry]
        let suggestions: [CompendiumEntry]?
        // not used by the view (store is used directly) but here to ensure the view is re-evaluated
        let presentedItemDetail: String?

        let scrollTo: String?

        init(_ state: CompendiumIndexState) {
            self.title = state.title
            self.entries = state.results.value ?? []

            if state.results.input.text?.nonEmptyString == nil && Set(state.results.input.filters?.types ?? []) == Set(state.properties.typeRestriction ?? []) {
                self.suggestions = state.suggestions?.nonEmptyArray
            } else {
                self.suggestions = nil
            }

            self.presentedItemDetail = state.presentedNextItemDetail?.navigationStackItemStateId
                ?? state.presentedDetailItemDetail?.navigationStackItemStateId

            self.scrollTo = state.scrollTo
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        func eq<E>(_ lhs: E, _ rhs: Any) -> Bool where E: Equatable {
            lhs == (rhs as? E)
        }

        return lhs.viewStore.state == rhs.viewStore.state && eq(lhs.viewProvider.state(), rhs.viewProvider.state())
    }
}

fileprivate struct CompendiumItemRow: View {
    @EnvironmentObject var env: Environment

    fileprivate var store: Store<CompendiumIndexState, CompendiumIndexAction>

    let item: CompendiumItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title)
            item.localizedSummary(in: ViewStore(store).state, env: env)
                .font(.footnote)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.leading)
        }
    }
}

struct FilterButton: View {
    @EnvironmentObject var env: Environment

    @ObservedObject var viewStore: ViewStore<CompendiumIndexState.Query, CompendiumIndexAction>
    let allAllowedItemTypes: [CompendiumItemType]

    @State var sheet: CompendiumFilterSheet?

    var body: some View {
        Menu {
            Picker(
                "Type",
                selection: viewStore.binding(
                    get: { $0.filters?.types?.single },
                    send: { .onQueryTypeFilterDidChange($0.optionalArray, debounce: false)}
                )
            ) {
                ForEach(allAllowedItemTypes, id: \.rawValue) { type in
                    Text("\(type.localizedScreenDisplayName)").tag(Optional.some(type))
                }
            }

            Divider()

            Button {
                presentFilterSheet()
            } label: {
                Text("More...")
            }
        } label: {
            let label: String = {
                if viewStore.state.filters == nil || viewStore.state.filters == .init() {
                    return "Filter"
                } else {
                    return "Filters active"
                }
            }()

            Button(action: {

            }) {
                Label(label, systemImage: "slider.horizontal.3")
            }
        } primaryAction: {
            presentFilterSheet()
        }
        .menuOrder(.fixed)
        .sheet(item: $sheet) { popover in
            AutoSizingSheetContainer {
                popover
            }
        }
    }

    var filtersAreActive: Bool {
        viewStore.state.filters?.test != nil
    }

    private func presentFilterSheet() {
        let state = CompendiumFilterSheetState(
            self.viewStore.state.filters,
            allAllowedItemTypes: allAllowedItemTypes
        )

        self.sheet = CompendiumFilterSheet(store: Store(initialState: state, reducer: CompendiumFilterSheetState.reducer, environment: self.env)) { filterValues in
            var filters = self.viewStore.state.filters ?? CompendiumIndexState.Query.Filters(types: nil)
            filters.types = filterValues.itemType.optionalArray
            filters.minMonsterChallengeRating = filterValues.minMonsterCR
            filters.maxMonsterChallengeRating = filterValues.maxMonsterCR
            self.viewStore.send(.query(.onFiltersDidChange(filters), debounce: false))
            self.sheet = nil
        }
    }
}

extension CompendiumFilterSheet: Identifiable {
    var id: AnyHashable {
        "CompendiumFilterSheet"
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
                    components.append(Text("Level \(level) \(type.localizedDisplayName)"))
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

// Used for communicating with the filter popover
fileprivate extension CompendiumFilterSheetState {
    init(_ queryFilters: CompendiumIndexState.Query.Filters?, allAllowedItemTypes: [CompendiumItemType]) {
        let values = Values(
            itemType: queryFilters?.types?.single,
            minMonsterCR: queryFilters?.minMonsterChallengeRating,
            maxMonsterCR: queryFilters?.maxMonsterChallengeRating
        )
        self.initial = values
        self.current = values

        self.allAllowedItemTypes = allAllowedItemTypes
    }
}
