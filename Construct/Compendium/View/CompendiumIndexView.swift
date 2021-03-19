//
//  CompendiumIndexView.swift
//  SwiftUITest
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

    var store: Store<CompendiumIndexState, CompendiumIndexAction>
    var viewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>

    @ObservedObject var localViewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>
    let viewProvider: ViewProvider

    @State var didFocusOnSearch = false

    init(store: Store<CompendiumIndexState, CompendiumIndexAction>, viewProvider: ViewProvider = .default) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.localViewStore = ViewStore(store, removeDuplicates: {
            $0.normalizedForDeduplication == $1.normalizedForDeduplication
        })
        self.viewProvider = viewProvider
    }

    var body: some View {
        return VStack {
            BorderedSearchField(
                text: localViewStore.binding(get: { $0.results.input.text.nonNilString }, send: { .query(.onTextDidChange($0), debounce: true) }),
                accessory: filterButton()
            )
            .introspectTextField { textField in
                if !textField.isFirstResponder, viewStore.state.properties.initiallyFocusOnSearch, !didFocusOnSearch {
                    textField.becomeFirstResponder()
                    didFocusOnSearch = true
                }
            }
            .padding([.leading, .top, .trailing], 8)

            if localViewStore.state.results.value != nil {
                CompendiumItemList(store: store, viewStore: ViewStore(store), entries: localViewStore.state.results.value!, viewProvider: viewProvider)
            } else if localViewStore.state.results.error != nil {
                Text("Loading failed").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if localViewStore.state.results.result.isLoading {
                Text("Loading...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                IfLetStore(store.scope(state: { $0.properties.initialContent.toc }).actionless) { store in
                    CompendiumTocView(parent: self, viewStore: ViewStore(store))
                }
            }

            if localViewStore.state.properties.showAdd && localViewStore.state.canAddItem {
                (localViewStore.state.results.input.filters?.types?.single).map { type in
                    HStack {
                        RoundedButton(action: {
                            self.localViewStore.send(.onAddButtonTap)
                        }) {
                            Label("Add \(type.localizedDisplayName)", systemImage: "plus.circle")
                        }
                    }
                    .padding([.leading, .trailing, .bottom], 8)
                }
            }
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            // Dismiss the keyboard when the user starts scrolling in the list
            env.dismissKeyboard()
        })
        .navigationBarTitle(localViewStore.state.navigationTitle)
        .navigationBarItems(trailing: Group {
            if localViewStore.state.properties.showImport {
                Button(action: {
                    self.viewStore.send(.setNextScreen(.compendiumImport(CompendiumImportViewState())))
                }) {
                    Text("Import").bold()
                }
            }
        })
        .onAppear {
            loadResultsIfNeeded()
        }
        // workaround for onAppear not getting called when a compendium index view is replaced by another
        // through the sidebar
        .onChange(of: viewStore.state.title) { _ in
            loadResultsIfNeeded()
        }
        // workaround: an inline NavigationLink inside navigationBarItems would be set to inactive
        // when the document picker of the import view is dismissed
        .stateDrivenNavigationLink(
            store: store,
            state: /CompendiumIndexState.NextScreen.compendiumImport,
            action: /CompendiumIndexAction.NextScreenAction.import,
            destination: { _ in CompendiumImportView() })
        .alert(store.scope(state: \.alert), dismiss: .alert(nil))
        .sheet(item: viewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
    }

    @ViewBuilder
    func filterButton() -> some View {
        if !localViewStore.state.compatibleFilterProperties.isEmpty {
            FilterButton(viewStore: viewStore)
        } else {
            EmptyView()
        }
    }

    private func loadResultsIfNeeded() {
        if self.viewStore.state.properties.initialContent.isSearchResults, self.viewStore.state.results.value == nil {
            self.viewStore.send(.query(.onTextDidChange(viewStore.state.results.input.text), debounce: false)) // kick-start search, fixme?
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: CompendiumIndexState.Sheet) -> some View {
        IfLetStore(
            store.scope(state: replayNonNil({ $0.creatureEditSheet }), action: { .creatureEditSheet($0) }),
            then: { store in
                SheetNavigationContainer {
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
    var parent: CompendiumIndexView

    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    @ObservedObject var viewStore: ViewStore<CompendiumIndexState.Properties.ContentDefinition.Toc, Never>

    var body: some View {
        List {
            Section {
                ForEach(viewStore.state.types, id: \.self) { type in
                    NavigationRowButton(action: {
                        let destination = CompendiumIndexState(
                            title: type.localizedScreenDisplayName,
                            properties: viewStore.state.destinationProperties,
                            results: .initial(type: type)
                        )
                        parent.viewStore.send(.setNextScreen(.compendiumIndex(destination)))
                    }) {
                        Text(type.localizedScreenDisplayName)
                            .foregroundColor(Color.primary)
                            .font(.headline)
                            .padding([.top, .bottom], 8)
                    }
                }
            }

            if !viewStore.state.suggested.isEmpty {
                Section(header: Text("Suggested")) {
                    ForEach(viewStore.state.suggested, id: \.key) { entry in
                        NavigationRowButton(action: {
                            if appNavigation == .tab {
                                parent.viewStore.send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                            } else {
                                parent.viewStore.send(.setDetailScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                            }
                        }) {
                            self.parent.viewProvider.row(self.parent.store, entry)
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
            store: parent.store,
            state: /CompendiumIndexState.NextScreen.compendiumIndex,
            action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
            destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
        )
        .stateDrivenNavigationLink(
            store: parent.store,
            state: /CompendiumIndexState.NextScreen.itemDetail,
            action: /CompendiumIndexAction.NextScreenAction.compendiumEntry,
            navDest: appNavigation == .tab ? .nextInStack : .detail,
            destination: { parent.viewProvider.detail($0) }
        )
    }
}

fileprivate struct CompendiumItemList: View {
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    var store: Store<CompendiumIndexState, CompendiumIndexAction>
    @ObservedObject var viewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>

    let entries: [CompendiumEntry]
    let viewProvider: CompendiumIndexView.ViewProvider

    var body: some View {
        let listHash = AnyHashable(entries.map { $0.key })
        return ScrollViewReader { scrollView in
            List {
                Section {
                    if entries.isEmpty {
                        Text("No results")
                    } else {
                        ForEach(entries, id: \.key) { entry in
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
                }
            }
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
                let entries = viewStore.state.results.value ?? []
                if let id = viewStore.state.scrollTo, entries.contains(where: { $0.key == id }) {
                    withAnimation {
                        scrollView.scrollTo(id)
                    }
                    viewStore.send(.scrollTo(nil))
                }
            }
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

    @ObservedObject var viewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>

    @State var popover: Popover?

    var body: some View {
        SimpleButton(action: {
            let state = CompendiumFilterPopoverState(self.viewStore.state.results.input.filters, self.viewStore.state.compatibleFilterProperties)

            self.popover = CompendiumFilterPopover(store: Store(initialState: state, reducer: CompendiumFilterPopoverState.reducer, environment: self.env)) { filterValues in
                var filters = self.viewStore.state.results.input.filters ?? CompendiumIndexState.Query.Filters(types: nil)
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
        viewStore.state.results.input.filters?.test != nil
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
