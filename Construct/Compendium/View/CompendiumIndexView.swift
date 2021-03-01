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
                switch localViewStore.state.properties.initialContent {
                case .toc(let toc):
                    CompendiumTocView(parent: self, toc: toc, store: store, viewStore: viewStore)
                case .searchResults:
                    Text("").frame(maxHeight: .infinity)
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
            if self.viewStore.state.properties.initialContent.isSearchResults, self.viewStore.state.results.value == nil {
                self.viewStore.send(.query(.onTextDidChange(viewStore.state.results.input.text), debounce: false)) // kick-start search, fixme?
            }
        }
        .stateDrivenNavigationLink(store: store, state: /CompendiumIndexState.NextScreen.creatureEdit, action: /CompendiumIndexAction.NextScreenAction.creatureEdit, isActive: { _ in true }, destination: { CreatureEditView(store: $0) })
        .stateDrivenNavigationLink(store: store, state: /CompendiumIndexState.NextScreen.groupEdit, action: /CompendiumIndexAction.NextScreenAction.itemGroupEdit, isActive: { _ in true }, destination: CompendiumItemGroupEditView.init)
        // workaround: an inline NavigationLink inside navigationBarItems would be set to inactive
        // when the document picker of the import view is dismissed
        .stateDrivenNavigationLink(
            store: store,
            state: /CompendiumIndexState.NextScreen.compendiumImport,
            action: /CompendiumIndexAction.NextScreenAction.import,
            isActive: { _ in true },
            destination: { _ in CompendiumImportView() })
        .alert(store.scope(state: \.alert), dismiss: .alert(nil))
    }

    @ViewBuilder
    func filterButton() -> some View {
        if !localViewStore.state.compatibleFilterProperties.isEmpty {
            FilterButton(viewStore: viewStore)
        } else {
            EmptyView()
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
    var parent: CompendiumIndexView

    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    var toc: CompendiumIndexState.Properties.ContentDefinition.Toc
    var store: Store<CompendiumIndexState, CompendiumIndexAction>
    var viewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>

    var body: some View {
        List {
            Section {
                if toc.types.contains(.monster) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /CompendiumIndexState.NextScreen.compendiumIndex,
                        action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                        isActive: { $0.title == "Monsters" }, // not great
                        initialState: CompendiumIndexState(title: "Monsters", properties: toc.destinationProperties, results: .initial(type: .monster)),
                        destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                    ) {
                        Text("Monsters").font(.headline).padding([.top, .bottom], 8)
                    }
                }

                if toc.types.contains(.character) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /CompendiumIndexState.NextScreen.compendiumIndex,
                        action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                        isActive: { $0.title == "Characters" }, // not great
                        initialState: CompendiumIndexState(title: "Characters", properties: toc.destinationProperties, results: .initial(type: .character)),
                        destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                    ) {
                        Text("Characters").font(.headline).padding([.top, .bottom], 8)
                    }
                }

                if toc.types.contains(.group) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /CompendiumIndexState.NextScreen.compendiumIndex,
                        action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                        isActive: { $0.title == "Adventuring Parties" }, // not great
                        initialState: CompendiumIndexState(title: "Adventuring Parties", properties: toc.destinationProperties, results: .initial(type: .group)),
                        destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                    ) {
                        Text("Adventuring Parties").font(.headline).padding([.top, .bottom], 8)
                    }
                }

                if toc.types.contains(.spell) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /CompendiumIndexState.NextScreen.compendiumIndex,
                        action: /CompendiumIndexAction.NextScreenAction.compendiumIndex,
                        isActive: { $0.title == "Spells" }, // not great
                        initialState: CompendiumIndexState(title: "Spells", properties: toc.destinationProperties, results: .initial(type: .spell)),
                        destination: { CompendiumIndexView(store: $0, viewProvider: parent.viewProvider) }
                    ) {
                        Text("Spells").font(.headline).padding([.top, .bottom], 8)
                    }
                }
            }

            if !toc.suggested.isEmpty {
                Section(header: Text("Suggested")) {
                    ForEach(toc.suggested, id: \.key) { entry in
                        StateDrivenNavigationLink(
                            store: store,
                            state: /CompendiumIndexState.NextScreen.itemDetail,
                            action: /CompendiumIndexAction.NextScreenAction.compendiumEntry,
                            navDest: appNavigation == .tab ? .nextInStack : .detail,
                            isActive: { $0.entry.key == entry.key },
                            initialState: CompendiumEntryDetailViewState(entry: entry),
                            destination: { parent.viewProvider.detail($0) }
                        ) {
                            self.parent.viewProvider.row(self.store, entry)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
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
                            StateDrivenNavigationLink(
                                store: store,
                                state: /CompendiumIndexState.NextScreen.itemDetail,
                                action: /CompendiumIndexAction.NextScreenAction.compendiumEntry,
                                navDest: appNavigation == .tab ? .nextInStack : .detail,
                                isActive: { $0.entry.key == entry.key },
                                initialState: CompendiumEntryDetailViewState(entry: entry),
                                destination: { viewProvider.detail($0) }
                            ) {
                                self.viewProvider.row(self.store, entry)
                            }
                        }
                    }
                }
            }
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
