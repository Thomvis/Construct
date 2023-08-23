//
//  EncounterDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 06/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import Helpers
import GameModels

struct EncounterDetailView: View {
    @EnvironmentObject var environment: Environment
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    var store: Store<EncounterDetailViewState, EncounterDetailViewState.Action>
    @ObservedObject var viewStore: ViewStore<EncounterDetailViewState, EncounterDetailViewState.Action>

    init(store: Store<EncounterDetailViewState, EncounterDetailViewState.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
    }

    var encounter: Encounter {
        viewStore.state.encounter
    }

    var body: some View {
        List(selection: Binding(get: {
            self.viewStore.state.selection
        }, set: {
            self.viewStore.send(.selection($0))
        })) {
            if viewStore.state.shouldShowEncounterDifficulty {
                Section {
                    SimpleButton(action: {
                        self.viewStore.send(.sheet(.settings))
                    }) {
                        if let difficulty = EncounterDifficulty(
                            party: encounter.partyWithEntriesForDifficulty.1,
                            monsters: encounter.combatants.compactMap { $0.definition.stats.challengeRating }
                        ) {
                            EncounterDifficultyView(difficulty: difficulty)
                        } else {
                            Text("Cannot calculate difficulty for current settings. Tap to change.")
                                .multilineTextAlignment(.center)
                                .font(.callout)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }

            if viewStore.state.encounter.combatants.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("Empty encounter").font(.headline)
                        Text("Start by adding one or more combatants.")
                    }.frame(maxWidth: .infinity).padding(18)
                }
            } else {
                CombatantSection(
                    parent: self,
                    title: "Combatants",
                    encounter: viewStore.state.encounter,
                    running: viewStore.state.running,
                    combatants: viewStore.state.encounter.combatantsInDisplayOrder
                )
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.defaultMinListRowHeight, 0.0) // this fixed the CombatantRow height
        .environment(\.editMode, Binding(get: {
            self.viewStore.state.editMode
        }, set: {
            self.viewStore.send(.editMode($0))
        }))
        .safeAreaInset(edge: .bottom) {
            actionBar()
        }
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
        .toolbar {
            toolbar()
        }
        .sheet(item: viewStore.binding(get: \.sheet) { _ in .sheet(nil) }, onDismiss: {
            self.viewStore.send(.sheet(nil))
        }, content: self.sheetView)
        .popover(popover)
        .onAppear {
            self.viewStore.send(.onAppear)
        }
    }

    @ViewBuilder
    func actionBar() -> some View {
        Group {
            if viewStore.state.running == nil {
                if viewStore.state.editMode == .active {
                    buildingEditModeActionBar()
                } else {
                    defaultActionBar()
                }
            } else {
                if viewStore.state.editMode == .active {
                    runningEditModeActionBar()
                } else {
                    RunningEncounterActionBar(viewStore: viewStore)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .padding(8)
    }

    func defaultActionBar() -> some View {
        // bug: buttonStyle(.plain) used below is needed for the correct layout of the buttons,
        // it does not make the button look plain
        return RoundedButtonToolbar {
            if viewStore.state.building.isScratchPad {
                Menu(content: {
                    Button(action: {
                        viewStore.send(.resetEncounter(false))
                    }) {
                        Text("Clear monsters").foregroundColor(Color.red)
                    }

                    Button(action: {
                        viewStore.send(.resetEncounter(true))
                    }) {
                        Text("Clear all").foregroundColor(Color.red)
                    }
                }) {
                    Button(action: { }) {
                        Label("Reset…", systemImage: "xmark.circle")
                    }
                    .accessibilityHint(Text("Activate to clear the encounter."))
                    .buttonStyle(.plain)
                }
                .disabled(self.viewStore.state.building.combatants.isEmpty)
            }

            Button(action: {

            }) {
                Label("Add combatants", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .menu(content: {
                Button(action: {
                    self.viewStore.send(.sheet(.add(AddCombatantSheet(state: AddCombatantState(encounter:
                        self.viewStore.state.encounter)))))
                    self.viewStore.send(.addCombatant(.quickCreate))
                }) {
                    Text("Quick create")
                    Image(systemName: "plus.circle")
                }
            }, primaryAction: {
                if appNavigation == .tab {
                    self.viewStore.send(.sheet(.add(AddCombatantSheet(state: AddCombatantState(encounter: self.viewStore.state.encounter)))))
                } else {
                    self.viewStore.send(.showAddCombatantReferenceItem)
                }
            })

            if let resumables = viewStore.state.resumableRunningEncounters.value, resumables.count > 0 {
                Menu(content: {
                    Button(action: {
                        viewStore.send(.run(nil), animation: .default)
                    }) {
                        Label("Start new run", systemImage: "plus.circle")
                    }

                    Divider()

                    with(RelativeDateTimeFormatter()) { formatter in
                        ForEach(resumables, id: \.key) { r in
                            Button(action: {
                                viewStore.send(.onResumeRunningEncounterTap(r.key), animation: .default)
                            }) {
                                Label(
                                    "Resume run from \(formatter.localizedString(for: r.modifiedAt, relativeTo: Date()))",
                                    systemImage: "play"
                                )
                            }
                        }
                    }
                }) {
                    Button(action: {
                        viewStore.send(.run(nil), animation: .default)
                    }) {
                        Label("Run encounter", systemImage: "play")
                    }
                    .disabled(self.viewStore.state.building.combatants.isEmpty)
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: {
                    viewStore.send(.run(nil), animation: .default)
                }) {
                    Label("Run encounter", systemImage: "play")
                }
                .disabled(self.viewStore.state.building.combatants.isEmpty)
            }
        }
        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
    }

    func buildingEditModeActionBar() -> some View {
        return RoundedButtonToolbar {
            Button(action: {
                self.viewStore.send(.selectionEncounterAction(.duplicate))
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .disabled(viewStore.state.selection.isEmpty)

            Button(action: {
                self.viewStore.send(.selectionEncounterAction(.remove))
            }) {
                Label("Remove", systemImage: "trash")
            }
            .disabled(viewStore.state.selection.isEmpty)
        }
    }

    func runningEditModeActionBar() -> some View {
        RoundedButtonToolbar {
            Button(action: {
                self.viewStore.send(.selectionCombatantAction(.hp(.current(.set(0)))))
            }) {
                Label("Eliminate", systemImage: "heart.slash")
            }
            .disabled(viewStore.state.selection.isEmpty)

            Button(action: {
                let selection = self.viewStore.state.selection.compactMap { self.viewStore.state.encounter.combatant(for: $0) }
                let state = CombatantTagsViewState(
                    combatants: selection,
                    effectContext: self.viewStore.state.running.map {
                        EffectContext(
                            source: nil,
                            targets: selection,
                            running: $0
                        )
                    }
                )
                self.viewStore.send(.sheet(.selectedCombatantTags(state)))
            }) {
                Label("Tags...", systemImage: "tag")
            }
            .disabled(viewStore.state.selection.isEmpty)

            Button(action: {
                self.viewStore.send(.popover(.health(.selection)))
            }) {
                Label("Health...", systemImage: "suit.heart")
            }
            .disabled(viewStore.state.selection.isEmpty)
        }
    }

    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {
                self.viewStore.send(.editMode(self.viewStore.state.editMode.isEditing ? .inactive : .active), animation: .default)
            }) {
                Text(self.viewStore.state.editMode.isEditing ? "Done" : "Edit")
            }

            if viewStore.state.running == nil {
                Menu {
                    if viewStore.state.isMechMuseEnabled {
                        Button {
                            viewStore.send(.onGenerateCombatantTraitsButtonTap)
                        } label: {
                            Label("Combatant Traits", systemImage: "quote.bubble")
                        }
                    }

                    Button {
                        viewStore.send(.sheet(.settings))
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                    Divider()

                    FeedbackMenuButton {
                        viewStore.send(.onFeedbackButtonTap)
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    func sheetView(_ sheet: EncounterDetailViewState.Sheet) -> some View {
        switch sheet {
        case .add:
            return IfLetStore(store.scope(state: replayNonNil({ $0.addCombatantState }), action: { .addCombatant($0) })) { store in
                AddCombatantView(store: store, onSelection: {
                    viewStore.send(.addCombatantAction($0, $1))
                }).environmentObject(self.environment)
            }.eraseToAnyView
        case .combatant:
            return IfLetStore(store.scope(state: replayNonNil({ $0.combatantDetailState }), action: { .combatantDetail($0) })) { store in
                CombatantDetailContainerView(store: store).environmentObject(self.environment)
            }.eraseToAnyView
        case .runningEncounterLog:
            return IfLetStore(store.scope(state: replayNonNil({ $0.runningEncounterLogState }), action: { fatalError() })) { store in
                SheetNavigationContainer {
                    RunningEncounterLogView(store: store).environmentObject(self.environment)
                }
            }.eraseToAnyView
        case .selectedCombatantTags:
            return IfLetStore(store.scope(state: replayNonNil({ $0.selectedCombatantTagsState }), action: { .selectedCombatantTags($0) })) { store in
                SheetNavigationContainer {
                    CombatantTagsView(store: store)
                }.environmentObject(self.environment)
            }.eraseToAnyView
        case .settings:
            return EncounterSettingsView(store: self.store).environmentObject(self.environment).eraseToAnyView
        case .generateCombatantTraits:
            return IfLetStore(store.scope(state: replayNonNil(\.generateCombatantTraitsState), action: EncounterDetailViewState.Action.generateCombatantTraits)) { store in
                SheetNavigationContainer {
                    GenerateCombatantTraitsView(store: store)
                }
            }.eraseToAnyView
        }
    }

    private var addCombatantOnSelection: (AddCombatantView.Action, Bool) -> Void {
        return { action, dismiss in
            switch action {
            case .add(let combatants):
                for c in combatants {
                    self.viewStore.send(.encounter(.add(c)))
                }
            case .addByKey(let keys, let party):
                for key in keys {
                    self.viewStore.send(.encounter(.addByKey(key, party)))
                }
            case .remove(let definitionID, let quantity):
                quantity.times {
                    if let combatant = self.viewStore.state.encounter.combatants(with: definitionID).last {
                        self.viewStore.send(.encounter(.remove(combatant)))
                    }
                }
            }

            if dismiss {
                self.viewStore.send(.sheet(nil))
            }
        }
    }

    var popover: Binding<AnyView?> {
        Binding(get: {
            guard let popover = viewStore.popover else { return nil }
            switch popover {
            case .combatantInitiative(let combatant, _):
                return IfLetStore(store.scope(state: { $0.combatantInitiativePopover }, action: { .combatantInitiativePopover($0) })) { store in
                    NumberEntryPopover(store: store) { value in
                        viewStore.send(.encounter(.combatant(combatant.id, .initiative(value))))
                        viewStore.send(.popover(nil))
                    }
                }.eraseToAnyView
            case .encounterInitiative:
                return InitiativePopover { settings in
                    viewStore.send(.encounter(.initiative(settings)))
                    viewStore.send(.popover(nil))
                }.makeBody()
            case .health(let target):
                return HealthDialog(environment: environment, hp: nil) { action in
                    switch target {
                    case .single(let combatant):
                        viewStore.send(.encounter(.combatant(combatant.id, action)))
                    case .selection:
                        viewStore.send(.selectionCombatantAction(action))
                    }
                    viewStore.send(.popover(nil))
                }.eraseToAnyView
            }
        }, set: {
            if $0 == nil {
                viewStore.send(.popover(nil))
            }
        })
    }
}

struct CombatantSection: View {
    let parent: EncounterDetailView
    let title: String
    let encounter: Encounter
    let running: RunningEncounter?
    let combatants: [Combatant]

    var body: some View {
        Section(header: Group {
            HStack {
                if parent.viewStore.state.editMode == .active {
                    with(Set(self.parent.viewStore.state.encounter.combatants.map { $0.id })) { allIds in
                        with(parent.viewStore.state.selection == allIds) { selectedAll in
                            Button(action: {
                                if selectedAll {
                                    self.parent.viewStore.send(.selection(Set()))
                                } else {
                                    self.parent.viewStore.send(.selection(allIds))
                                }
                            }) {
                                Text(selectedAll ? "Deselect All" : "Select All")
                            }
                        }
                    }
                } else {
                    Image(systemName: "heart").frame(width: 25)
                        .accessibility(hidden: true)
                    Text(title).bold()
                }

                Spacer()
                Image(systemName: "hare")
                    .accessibility(hidden: true)
            }
        }, footer: Group {
            EmptyView() // TODO
        }) {
            ForEach(combatants, id: \.id) { combatant in
                CombatantRow(encounter: self.encounter, running: self.running, combatant: combatant, onHealthTap: {
                    self.parent.viewStore.send(.popover(.health(.single(combatant))))
                }, onInitiativeTap: {
                    self.parent.viewStore.send(.popover(.combatantInitiative(combatant, NumberEntryViewState.initiative(combatant: combatant))), animation: .default)
                })
                .accentColor(Color.primary)
                // contentShape is needed or else the tapGesture on the whole cell doesn't work
                // scale is used to make the row easier selectable in edit mode
                .contentShape(Rectangle().scale(self.parent.viewStore.state.editMode.isEditing ? 0 : 1))
                .onTapGesture {
                    if parent.appNavigation == .tab {
                        self.parent.viewStore.send(.sheet(.combatant(CombatantDetailViewState(runningEncounter: self.parent.viewStore.state.running, combatant: combatant))))
                    } else {
                        self.parent.viewStore.send(.showCombatantDetailReferenceItem(combatant))
                    }
                }
                // Using a menu (instead of a contextMenu) here would be nice, but it blocks interaction with the row's content
                .contextMenu {
                    Button(action: {
                        self.parent.viewStore.send(.encounter(.remove(combatant)))
                    }) {
                        Text("Remove")
                        Image(systemName: "trash")
                    }

                    if !combatant.definition.isUnique {
                        Button(action: {
                            self.parent.viewStore.send(.encounter(.duplicate(combatant)))
                        }) {
                            Text("Duplicate")
                            Image(systemName: "plus.square.on.square")
                        }
                    }

                    if !combatant.isDead {
                        Button(action: {
                            self.parent.viewStore.send(.encounter(.combatant(combatant.id, .hp(.current(.set(0))))))
                        }) {
                            Text("Eliminate")
                            Image(systemName: "heart.slash")
                        }
                    }

                    Button(action: {
                        self.parent.viewStore.send(.encounter(.combatant(combatant.id, .reset(hp: true, initiative: true, resources: true, tags: true))))
                    }) {
                        Text("Reset")
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .onDelete(perform: self.onDelete)
        }
    }

    func onDelete(_ indices: IndexSet) {
        for i in indices {
            parent.viewStore.send(.encounter(.remove(combatants[i])))
        }
    }
}

@ViewBuilder
func FeedbackMenuButton(action: @escaping () -> Void) -> some View {
    Button {
        action()
    } label: {
        Label("Feedback…", systemImage: "exclamationmark.bubble")
    }
}

extension EncounterDetailViewState.Sheet: Identifiable {
    static let settingsUUID = UUID()
    static let combatantsTraitsUUID = UUID()

    var id: UUID {
        switch self {
        case .add(let s): return s.id
        case .combatant(let s): return s.combatant.id.rawValue
        case .runningEncounterLog(let s): return s.encounter.id.rawValue
        case .selectedCombatantTags: return UUID(uuidString: "FA34879F-C2AB-4B0C-A281-50404D56118C")!
        case .settings: return Self.settingsUUID
        case .generateCombatantTraits: return Self.combatantsTraitsUUID
        }
    }
}

extension EncounterDetailViewState {
    var shouldShowEncounterDifficulty: Bool {
        running == nil
            && !encounter.combatants.isEmpty
    }
}
