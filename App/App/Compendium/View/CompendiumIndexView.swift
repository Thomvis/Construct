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
import Compendium

struct CompendiumIndexView<BottomBarButtons>: View where BottomBarButtons: View {
    @EnvironmentObject var env: Environment

    let store: Store<CompendiumIndexState, CompendiumIndexAction>

    let viewProvider: CompendiumIndexViewProvider

    let bottomBarButtons: () -> BottomBarButtons

    init(
        store: Store<CompendiumIndexState, CompendiumIndexAction>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons
    ) {
        self.store = store
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    init(
        store: Store<CompendiumIndexState, CompendiumIndexAction>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons = { EmptyView() }
    ) where BottomBarButtons == EmptyView {
        self.store = store
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    var body: some View {
        WithViewStore(store.scope(state: { LocalState($0) })) { localViewStore in
            Group {
                contentView(localViewStore)
            }
            .safeAreaInset(edge: .bottom) {
                roundedButtonToolbar(localViewStore)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitle(localViewStore.state.title, displayMode: .inline)
            .toolbar {
                if localViewStore.state.showImportButton {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            localViewStore.send(.setNextScreen(.compendiumImport(CompendiumImportViewState())))
                        } label: {
                            Text("Import...")
                        }
                    }
                }
            }
            .onAppear {
                loadResultsIfNeeded(localViewStore)
            }
            .sheet(item: localViewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
        }
        .modifier(CompendiumSearchableModifier(store: store))
        .alert(store.scope(state: \.alert), dismiss: .alert(nil))
        // workaround: an inline NavigationLink inside navigationBarItems would be set to inactive
        // when the document picker of the import view is dismissed
        .stateDrivenNavigationLink(
            store: store,
            state: /CompendiumIndexState.NextScreen.compendiumImport,
            action: /CompendiumIndexAction.NextScreenAction.import,
            destination: { _ in CompendiumImportView() }
        )
    }

    @ViewBuilder
    func contentView(_ localViewStore: ViewStore<LocalState, CompendiumIndexAction>) -> some View {
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
            CompendiumItemList(store: store, viewProvider: viewProvider)
        case .failedWithError:
            Text("Loading failed").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func roundedButtonToolbar(_ localViewStore: ViewStore<LocalState, CompendiumIndexAction>) -> some View {
        RoundedButtonToolbar {
            bottomBarButtons()

            if localViewStore.state.showAddButton {
                let addableTypes = localViewStore.state.addableItemTypes
                if let type = addableTypes.single {
                    Button(action: {
                        localViewStore.send(.onAddButtonTap(type))
                    }) {
                        Label("Add \(type.localizedDisplayName)", systemImage: "plus.circle")
                    }
                } else {
                    Menu {
                        ForEach(addableTypes, id: \.rawValue) { type in
                            Button {
                                localViewStore.send(.onAddButtonTap(type))
                            } label: {
                                Text("New \(type.localizedDisplayName)")
                            }
                        }
                    } label: {
                        Button(action: {

                        }) {
                            Label("Add", systemImage: "plus.circle")
                        }
                        // bug: ignoresSafeArea() is needed to prevent a layout glitch when the keyboard is presented
                        .ignoresSafeArea()
                    }
                    .menuStyle(.borderlessButton)
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

    private func loadResultsIfNeeded(_ localViewStore: ViewStore<LocalState, CompendiumIndexAction>) {
        if !localViewStore.state.results.isSuccess {
            localViewStore.send(.results(.result(.didShowElementAtIndex(0)))) // kick-start search, fixme?
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

        let itemTypeRestriction: [CompendiumItemType]?
        let itemTypeFilter: [CompendiumItemType]?
        let showAddButton: Bool

        let title: String
        let showImportButton: Bool

        let isShowingImport: Bool
        @EqKey({ $0?.id })
        var sheet: CompendiumIndexState.Sheet?

        init(_ state: CompendiumIndexState) {
            if let resValues = state.results.entries {
                self.results = resValues.isEmpty ? .succeededWithoutResults : .succeededWithResults
            } else if state.results.error != nil {
                self.results = .failedWithError
            } else {
                self.results = .loadingInitialContent
            }

            itemTypeRestriction = state.properties.typeRestriction
            itemTypeFilter = CompendiumIndexState.itemTypeFilter(input: state.results.input, properties: state.properties)
            showAddButton = state.properties.showAdd

            title = state.title
            showImportButton = state.properties.showImport

            isShowingImport = state.presentedNextCompendiumImport != nil || state.presentedDetailCompendiumImport != nil

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

/// This modifier applies the searchable modifier to the view it is applied to
/// This is done in a convoluted way to work around a glitch in the searchable modifier:
/// When the searchable modifier is inside a WithViewStore, fast text entry can cause the
/// cursor to not remain at the end of the text. Example: fast entry of "Goblin" can result
/// in "Gobin|l" (where | is the position of the cursor after text entry)
///
/// Using searchable with `tokens` makes the issue more apparent.
fileprivate struct CompendiumSearchableModifier: ViewModifier {
    let store: Store<CompendiumIndexState, CompendiumIndexAction>

    @State var text: String = ""
    @State var tokens: [CompendiumItemType] = []

    func body(content: Content) -> some View {
        content.searchable(
            text: $text,
            tokens: $tokens,
            token: { type in
                Text(type.localizedScreenDisplayName)
            }
        )
        .onChange(of: text, perform: { t in
            ViewStore(store).send(.query(.onTextDidChange(t.nonEmptyString)))
        })
        .onChange(of: tokens) { tokens in
            ViewStore(store).send(.onQueryTypeFilterDidChange(tokens.nonEmptyArray))
        }
        .background {
            WithViewStore(store, observe: LocalState.init) { localViewStore in
                Color.clear
                    .onChange(of: localViewStore.state.searchText) { t in
                        if t.nonNilString != text {
                            text = t.nonNilString
                        }
                    }
                    .onChange(of: localViewStore.state.itemTypeFilter) { filter in
                        if filter != tokens {
                            tokens = filter
                        }
                    }
                    .onAppear {
                        text = localViewStore.state.searchText.nonNilString
                        tokens = localViewStore.state.itemTypeFilter
                    }
            }
        }
    }

    struct LocalState: Equatable {
        let searchText: String?
        let itemTypeFilter: [CompendiumItemType]

        init(_ parentState: CompendiumIndexState) {
            self.searchText = parentState.results.input.text
            self.itemTypeFilter = CompendiumIndexState.itemTypeFilter(input: parentState.results.input, properties: parentState.properties) ?? []
        }
    }
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
            List {
                if state.useNamedSections {
                    if let suggestions = state.suggestions {
                        section(header: Text("Suggestions"), entries: suggestions)
                    }

                    if let typeFilters = state.typeFilters {
                        typeFilterSection(typeFilters: typeFilters)
                    }

                    if !state.entries.isEmpty {
                        section(header: Text("All"), entries: state.entries, reportVisibility: true)
                    }
                } else {
                    section(header: EmptyView(), entries: state.entries, reportVisibility: true)
                }

                if viewStore.state.isLoadingMoreEntries {
                    VStack(spacing: 12) {
                        // work-around: the regular ProgressView() does not show during subsequent loads, so we use our own
                        AnimatingSymbol(systemName: "ellipsis")
                            .font(.title)

                        Text("Loading more entries…")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .listRowSeparator(.hidden)
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
    func section<H>(header: H, entries: [CompendiumEntry], reportVisibility: Bool = false) -> some View where H: View  {
        let indexByKey = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.key, $0.offset) })

        Section(header: header) {
            ForEach(entries, id: \.key) { entry in
                NavigationRowButton(action: {
                    viewStore.send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                }) {
                    let itemView = viewProvider.row(self.store, entry)

                    if reportVisibility {
                        itemView.onAppear {
                            if let idx = indexByKey[entry.key] {
                                viewStore.send(.results(.result(.didShowElementAtIndex(idx))))
                            }
                        }
                    } else {
                        itemView
                    }
                }
            }
        }
    }

    func section(entries: [CompendiumEntry]) -> some View {
        section(header: EmptyView(), entries: entries)
    }

    func typeFilterSection(typeFilters: [CompendiumItemType]) -> some View {
        Section(header: Text("Filter")) {
            ForEach(typeFilters, id: \.self) { t in
                Button {
                    viewStore.send(.onQueryTypeFilterDidChange([t]))
                } label: {
                    HStack {
                        Text("\(t.localizedScreenDisplayName)").bold()
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                }
                .foregroundColor(Color.primary)
                .buttonStyle(.borderless)
            }
        }
    }

    struct LocalState: Equatable {
        let title: String
        let entries: [CompendiumEntry]
        let suggestions: [CompendiumEntry]?
        let typeFilters: [CompendiumItemType]?
        // not used by the view (store is used directly) but here to ensure the view is re-evaluated
        let presentedItemDetail: String?
        let isLoadingMoreEntries: Bool

        let scrollTo: CompendiumEntry.Key?

        init(_ state: CompendiumIndexState) {
            self.title = state.title
            self.entries = state.results.entries ?? []

            let input = state.results.inputForEntries
            if input?.text?.nonEmptyString == nil && Set(input?.filters?.types ?? []) == Set(state.properties.typeRestriction ?? []) {
                self.suggestions = state.suggestions?.nonEmptyArray
            } else {
                self.suggestions = nil
            }

            let itemTypeFilter = CompendiumIndexState.itemTypeFilter(input: input, properties: state.properties)
            /// Returns allowed item types (as per type restriction), but only if the user has not
            /// added a query or changed the type filter. If that's the case, an empty array is returned.
            typeFilters = input?.text?.nonEmptyString == nil && itemTypeFilter == nil
                    ? (state.properties.typeRestriction ?? CompendiumItemType.allCases)
                    : nil

            self.presentedItemDetail = state.presentedNextItemDetail?.navigationStackItemStateId
                ?? state.presentedDetailItemDetail?.navigationStackItemStateId
            self.isLoadingMoreEntries = state.results.isLoading

            self.scrollTo = state.scrollTo
        }

        var useNamedSections: Bool {
            suggestions != nil || typeFilters != nil
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
        let label: String = {
            if viewStore.state.filters == nil || viewStore.state.filters == .init() {
                return "Filter"
            } else {
                return "Filters active"
            }
        }()

        return Button(action: {
            presentFilterSheet()
        }) {
            Label(label, systemImage: "slider.horizontal.3")
        }
        .menuOrder(.fixed)
        .sheet(item: $sheet) { popover in
            AutoSizingSheetContainer {
                popover
            }
        }
    }

    private func presentFilterSheet() {
        let state = CompendiumFilterSheetState(
            self.viewStore.state.filters,
            allAllowedItemTypes: allAllowedItemTypes
        )

        self.sheet = CompendiumFilterSheet(store: Store(initialState: state, reducer: CompendiumFilterSheetState.reducer, environment: self.env)) { filterValues in
            var filters = self.viewStore.state.filters ?? .init()
            filters.types = filterValues.itemType.optionalArray
            filters.minMonsterChallengeRating = filterValues.minMonsterCR
            filters.maxMonsterChallengeRating = filterValues.maxMonsterCR
            filters.monsterType = filterValues.monsterType
            self.viewStore.send(.query(.onFiltersDidChange(filters)))
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
    init(_ queryFilters: CompendiumFilters?, allAllowedItemTypes: [CompendiumItemType]) {
        let values = Values(
            itemType: queryFilters?.types?.single,
            minMonsterCR: queryFilters?.minMonsterChallengeRating,
            maxMonsterCR: queryFilters?.maxMonsterChallengeRating,
            monsterType: queryFilters?.monsterType
        )
        self.initial = values
        self.current = values

        self.allAllowedItemTypes = allAllowedItemTypes
    }
}

fileprivate extension CompendiumIndexState {
    static func itemTypeFilter(input: Query?, properties: Properties) -> [CompendiumItemType]? {
        if Set(input?.filters?.types ?? []) == Set(properties.typeRestriction ?? CompendiumItemType.allCases) {
            return nil
        } else {
            return input?.filters?.types
        }
    }
}
