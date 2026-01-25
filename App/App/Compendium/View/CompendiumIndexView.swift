//
//  CompendiumIndexView.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import ComposableArchitecture
import BetterSafariView
import GameModels
import Helpers
import SharedViews
import Compendium

struct CompendiumIndexView<BottomBarButtons>: View where BottomBarButtons: View {
    @State var isSearching = false

    @Bindable var store: StoreOf<CompendiumIndexFeature>

    let viewProvider: CompendiumIndexViewProvider

    let bottomBarButtons: () -> BottomBarButtons

    init(
        store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons
    ) {
        self.store = store
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    init(
        store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>,
        viewProvider: CompendiumIndexViewProvider = .default,
        @ViewBuilder bottomBarButtons: @escaping () -> BottomBarButtons = { EmptyView() }
    ) where BottomBarButtons == EmptyView {
        self.store = store
        self.viewProvider = viewProvider
        self.bottomBarButtons = bottomBarButtons
    }

    var body: some View {
        Group {
            contentView
        }
        .safeAreaInset(edge: .bottom) {
            roundedButtonToolbar
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitle(store.title, displayMode: .inline)
        .toolbar {
            if store.showMenu {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        store.send(.setSelecting(!store.isSelecting), animation: .default)
                    } label: {
                        Label(
                            "Select",
                            systemImage: store.isSelecting ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                    }

                    Menu {
                        Button {
                            store.send(.setSheet(.documents(CompendiumDocumentsFeature.State())))
                        } label: {
                            Label("Manage Documents", systemImage: "line.3.horizontal.decrease")
                        }

                        Button {
                            store.send(.setSheet(.compendiumImport(CompendiumImportFeature.State())))
                        } label: {
                            Label("Import...", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Manage", systemImage: "books.vertical")
                    }
                }
            }
        }
        .onAppear {
            loadResultsIfNeeded()
        }
        .modifier(IsSearchingModifier(isSearching: $isSearching.animation(.default)))
        .modifier(CompendiumSearchableModifier(store: store))
        .modifier(Sheets(store: store))
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.resultsStatus {
        case .succeededWithoutResults:
            VStack(spacing: 18) {
                Text("No results").font(.title)

                Button("Search the web") {
                    store.send(.onSearchOnWebButtonTap)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safariView(
                item: Binding(
                    get: { store.safari },
                    set: { _ in store.send(.setSafari(nil)) }
                ),
                onDismiss: { store.send(.setSafari(nil)) },
                content: { state in
                    BetterSafariView.SafariView(
                        url: state.url
                    )
                }
            )
        case .succeededWithResults, .loadingInitialContent:
            CompendiumItemList(store: store, viewProvider: viewProvider)
        case .failedWithError:
            Text("Loading failed").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var roundedButtonToolbar: some View {
        RoundedButtonToolbar {
            bottomBarButtons()

            if store.showAddButton {
                let addableTypes = store.addableItemTypes
                if let type = addableTypes.single {
                    Button(action: {
                        store.send(.onAddButtonTap(type))
                    }) {
                        Label("Add \(type.localizedDisplayName)", systemImage: "plus.circle")
                    }
                } else {
                    Menu {
                        ForEach(addableTypes, id: \.rawValue) { type in
                            Button {
                                store.send(.onAddButtonTap(type))
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
                    .menuStyle(.borderlessButton)
                }
            }

            FilterButton(
                store: store,
                allAllowedItemTypes: store.allAllowedItemTypes,
                sourceRestriction: store.sourceRestriction
            )

            if store.isSelecting || isSearching {
                let keys = store.selectedKeys
                Menu {
                    // If the user is searching, the toggle selection mode button is not visible in the navigation bar
                    if isSearching {
                        Button {
                            store.send(.setSelecting(!store.isSelecting), animation: .default)
                        } label: {
                            Label(
                                "Select",
                                systemImage: store.isSelecting ? "checkmark.circle.fill" : "checkmark.circle"
                            )
                        }

                        Divider()
                    }

                    Button {
                        store.send(.onTransferSelectedMenuItemTap(.move))
                    } label: {
                        Label("Move selected...", systemImage: "arrow.right.doc.on.clipboard")
                    }
                    .disabled(keys.isEmpty)

                    Button {
                        store.send(.onTransferSelectedMenuItemTap(.copy))
                    } label: {
                        Label("Copy selected...", systemImage: "document.on.clipboard")
                    }
                    .disabled(keys.isEmpty)

                    Divider()

                    Button(role: .destructive) {
                        store.send(.onDeleteSelectedRequested)
                    } label: {
                        Label("Delete selected...", systemImage: "trash")
                    }
                    .disabled(keys.isEmpty)
                } label: {
                    Button(action: {

                    }) {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 50)
            }
        }
        .padding([.leading, .trailing, .bottom], 8)
    }

    private func loadResultsIfNeeded() {
        if !store.resultsStatus.isSuccess {
            store.send(.results(.result(.didShowElementAtIndex(0)))) // kick-start search, fixme?
        }
    }

    struct Sheets: ViewModifier {
        @Bindable var store: StoreOf<CompendiumIndexFeature>

        func body(content: Content) -> some View {
            content
                .sheet(
                    store: store.scope(state: \.$sheet.creatureEdit, action: \.sheet.creatureEdit)
                ) { store in
                    SheetNavigationContainer(isModalInPresentation: true) {
                        CreatureEditView(store: store)
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.groupEdit, action: \.sheet.groupEdit)
                ) { store in
                    SheetNavigationContainer {
                        CompendiumItemGroupEditView(store: store)
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.compendiumImport, action: \.sheet.compendiumImport)
                ) { store in
                    SheetNavigationContainer {
                        CompendiumImportView(store: store)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button {
                                        self.store.send(.sheet(.dismiss))
                                    } label: {
                                        Text("Cancel")
                                    }
                                }
                            }
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.documents, action: \.sheet.documents)
                ) { store in
                    SheetNavigationContainer {
                        CompendiumDocumentsView(store: store)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button {
                                        self.store.send(.sheet(.dismiss))
                                    } label: {
                                        Text("Done").bold()
                                    }
                                }
                            }
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.transfer, action: \.sheet.transfer)
                ) { store in
                    AutoSizingSheetContainer {
                        SheetNavigationContainer {
                            CompendiumItemTransferSheet(store: store)
                                .autoSizingSheetContent(constant: 40) // add 40 for the navigation bar
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.filter, action: \.sheet.filter)
                ) { filterStore in
                    AutoSizingSheetContainer {
                        CompendiumFilterSheet(store: filterStore) { _ in
                            self.store.send(.sheet(.presented(.onFilterApply)))
                        }
                    }
                }
        }
    }

}

struct CompendiumIndexViewProvider {
    let row: (Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>, CompendiumEntry) -> AnyView
    let detail: (Store<CompendiumEntryDetailFeature.State, CompendiumEntryDetailFeature.Action>) -> AnyView

    /// Can be used by the view to invalidate itself if the state changes
    let state: () -> any Equatable

    static let `default` = CompendiumIndexViewProvider(
        row: { store, entry in
            CompendiumEntryRow(store: store, entry: entry).eraseToAnyView
        },
        detail: { store in
            CompendiumEntryDetailView(store: store).eraseToAnyView
        },
        state: { 0 }
    )
}

/// This modifier applies the searchable modifier to the view it is applied to
fileprivate struct CompendiumSearchableModifier: ViewModifier {
    let store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>

    @State var text: String = ""
    @State var tokens: [CompendiumItemType] = []

    func body(content: Content) -> some View {
        let searchText = store.results.input.text
        let itemTypeFilter = store.currentItemTypeFilter ?? []
        
        content.searchable(
            text: $text,
            tokens: $tokens,
            token: { type in
                Text(type.localizedScreenDisplayName)
            }
        )
        .onChange(of: text) { _, t in
            store.send(.query(.onTextDidChange(t.nonEmptyString)))
        }
        .onChange(of: tokens) { _, tokens in
            store.send(.onQueryTypeFilterDidChange(tokens.nonEmptyArray))
        }
        .onChange(of: searchText) { _, t in
            if t.nonNilString != text {
                text = t.nonNilString
            }
        }
        .onChange(of: itemTypeFilter) { _, filter in
            if filter != tokens {
                tokens = filter
            }
        }
        .onAppear {
            text = searchText.nonNilString
            tokens = itemTypeFilter
        }
    }
}

private struct IsSearchingModifier: ViewModifier {
    @SwiftUI.Environment(\.isSearching) private var envIsSearching: Bool
    @Binding var isSearching: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: envIsSearching) { oldValue, newValue in
                isSearching = newValue
            }
    }
}

fileprivate struct CompendiumItemList: View {
    @Bindable var store: StoreOf<CompendiumIndexFeature>
    let viewProvider: CompendiumIndexViewProvider

    init(store: StoreOf<CompendiumIndexFeature>, viewProvider: CompendiumIndexViewProvider) {
        self.store = store
        self.viewProvider = viewProvider
    }

    var body: some View {
        let listHash = AnyHashable((store.entries + (store.displaySuggestions ?? [])).map { $0.key })

        return ScrollViewReader { scrollView in
            List(selection: Binding(
                get: { store.selectedKeys },
                set: { store.send(.setSelectedKeys($0)) }
            )) {
                if store.useNamedSections {
                    if let suggestions = store.displaySuggestions {
                        section(header: Text("Suggestions"), entries: suggestions)
                            .selectionDisabled()
                    }

                    if let typeFilters = store.displayTypeFilters {
                        typeFilterSection(typeFilters: typeFilters)
                            .selectionDisabled()
                    }

                    if !store.entries.isEmpty {
                        section(header: Text("All"), entries: store.entries, reportVisibility: true)
                    }
                } else {
                    section(header: EmptyView(), entries: store.entries, reportVisibility: true)
                }

                if store.isLoadingMoreEntries {
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
                    .selectionDisabled()
                    .transition(.opacity.animation(.default))
                }
            }
            .listStyle(.plain)
            // Workaround: without the id, the ForEach above would sometimes not be re-evaluated
            // (e.g. when switching between compendium types)
            // At the moment of writing, the sidebar navigation link to the compendium is made in a way
            // that a switch from one compendium type to another does not create a new CompendiumIndexView
            // instance
            .id(store.title)
            .environment(\.editMode, Binding(
                get: { store.isSelecting ? .active : .inactive },
                set: { store.send(.setSelecting($0 == .active)) }
            ))
            .navigationDestination(
                item: $store.scope(state: \.destination, action: \.destination)
            ) { destinationStore in
                switch destinationStore.case {
                case let .itemDetail(detailStore):
                    viewProvider.detail(detailStore)
                }
            }
            .onChange(of: [listHash, AnyHashable(store.scrollTo)]) { _, _ in
                let entries = store.entries
                if let id = store.scrollTo, entries.contains(where: { $0.key == id }) {
                    withAnimation {
                        scrollView.scrollTo(id)
                    }
                    store.send(.scrollTo(nil))
                }
            }
        }
    }

    @ViewBuilder
    func section<H>(header: H, entries: [CompendiumEntry], reportVisibility: Bool = false) -> some View where H: View  {
        let indexByKey = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.key, $0.offset) })

        Section(header: header) {
            ForEach(entries, id: \.item.key) { entry in
                NavigationRowButton(action: {
                    store.send(.setDestination(.itemDetail(CompendiumEntryDetailFeature.State(entry: entry))))
                }) {
                    let itemView = viewProvider.row(self.store, entry)

                    if reportVisibility {
                        itemView.onAppear {
                            if let idx = indexByKey[entry.key] {
                                store.send(.results(.result(.didShowElementAtIndex(idx))))
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
                    store.send(.onQueryTypeFilterDidChange([t]))
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
}

fileprivate struct CompendiumEntryRow: View {
    @EnvironmentObject var ordinalFormatter: OrdinalFormatter
    fileprivate var store: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>

    let entry: CompendiumEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.item.title).lineLimit(1)

                entry.item.localizedSummary(in: store.state, ordinalFormatter: ordinalFormatter)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
            }

            Spacer()

            if entry.error != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
            }

            if store.properties.showSourceDocumentBadges {
                Text(entry.document.id.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .padding([.leading, .trailing], 2)
                    .background(Color(UIColor.systemFill).clipShape(RoundedRectangle(cornerRadius: 4)))
            }
        }
    }
}

struct FilterButton: View {
    let store: StoreOf<CompendiumIndexFeature>
    let allAllowedItemTypes: [CompendiumItemType]
    let sourceRestriction: CompendiumFilters.Source?

    var body: some View {
        // todo: should it be "active" if filters are equal to the restrictions
        let filters = store.results.input.filters
        let label: String = {
            if filters == nil || filters == .init() {
                return "Filter"
            } else {
                return "Filters active"
            }
        }()

        return Menu {
            Button {
                store.send(.results(.input(.onFiltersDidChange(.init()))))
            } label: {
                Label("Clear filters", systemImage: "clear")
            }
            .disabled(filters == nil || filters == .init())

        } label: {
            Label(label, systemImage: "slider.horizontal.3")
        } primaryAction: {
            presentFilterSheet()
        }
    }

    private func presentFilterSheet() {
        let filters = store.results.input.filters
        let state = CompendiumFilterSheetFeature.State(
            filters,
            allAllowedItemTypes: allAllowedItemTypes,
            sourceRestriction: sourceRestriction
        )
        store.send(.setSheet(.filter(state)))
    }
}

extension CompendiumItem {
    func localizedSummary(in context: CompendiumIndexFeature.State, ordinalFormatter: OrdinalFormatter) -> Text? {
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
                var text = "\(ordinalFormatter.string(from: level)) level"
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
fileprivate extension CompendiumFilterSheetFeature.State {
    init(
        _ queryFilters: CompendiumFilters?,
        allAllowedItemTypes: [CompendiumItemType],
        sourceRestriction: CompendiumFilters.Source?
    ) {
        let values = Values(
            source: queryFilters?.source,
            itemType: queryFilters?.types?.single,
            minMonsterCR: queryFilters?.minMonsterChallengeRating,
            maxMonsterCR: queryFilters?.maxMonsterChallengeRating,
            monsterType: queryFilters?.monsterType
        )

        self.init(
            allAllowedItemTypes: allAllowedItemTypes,
            sourceRestriction: sourceRestriction,
            initial: values,
            current: values
        )
    }
}
