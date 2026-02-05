//
//  EncounterDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 06/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import ComposableArchitecture
import Foundation
import GameModels
import Helpers
import SharedViews
import SwiftUI

struct EncounterDetailView: View {
    @SwiftUI.Environment(\.appNavigation) var appNavigation: AppNavigation

    @Bindable var store: StoreOf<EncounterDetailFeature>

    var encounter: Encounter {
        store.state.encounter
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.environment["CONSTRUCT_UI_TESTS"] == "1"
    }

    var body: some View {
        List(
            selection: Binding(
                get: {
                    store.selection
                },
                set: {
                    store.send(.selection($0))
                })
        ) {
            if store.state.shouldShowEncounterDifficulty {
                Section {
                    SimpleButton(action: {
                        store.send(.setSheet(.settings))
                    }) {
                        if let difficulty = EncounterDifficulty(
                            party: encounter.partyWithEntriesForDifficulty.1,
                            monsters: encounter.combatants.compactMap {
                                $0.definition.stats.challengeRating
                            }
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

            if store.state.encounter.combatants.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("Empty encounter").font(.headline)
                        Text("Start by adding one or more combatants.")
                    }.frame(maxWidth: .infinity).padding(18)
                }
            } else {
                CombatantSection(
                    store: store,
                    appNavigation: appNavigation,
                    title: "Combatants",
                    encounter: store.state.encounter,
                    running: store.state.running,
                    combatants: store.state.encounter.combatantsInDisplayOrder
                )
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.defaultMinListRowHeight, 0.0)  // this fixed the CombatantRow height
        .environment(
            \.editMode,
            Binding(
                get: {
                    store.editMode
                },
                set: {
                    store.send(.editMode($0))
                })
        )
        .safeAreaInset(edge: .bottom) {
            actionBar()
        }
        .navigationBarTitle(Text(store.state.navigationTitle), displayMode: .inline)
        .toolbar {
            toolbar()
        }
        .modifier(Sheets(store: store))
        .popover(popover)
        .onAppear {
            store.send(.onAppear)
        }
    }

    struct Sheets: ViewModifier {
        @Bindable var store: StoreOf<EncounterDetailFeature>

        func body(content: Content) -> some View {
            content.sheet(item: $store.scope(state: \.sheet, action: \.sheet)) { store in
                switch store.state {
                case .add:
                    if let store = store.scope(state: \.add?.state, action: \.add) {
                        AddCombatantView(store: store, onSelection: { self.store.send(.addCombatantAction($0, $1)) })
                    }
                case .combatant:
                    if let store = store.scope(state: \.combatant, action: \.combatant) {
                        CombatantDetailView(store: store)
                    }
                case .runningEncounterLog:
                    if let store = store.scope(state: \.runningEncounterLog, action: \.runningEncounterLog) {
                        SheetNavigationContainer {
                            RunningEncounterLogView(store: store)
                        }
                    }
                case .selectedCombatantTags:
                    if let store = store.scope(state: \.selectedCombatantTags, action: \.selectedCombatantTags) {
                        SheetNavigationContainer {
                            CombatantTagsView(store: store)
                        }
                    }
                case .settings:
                    EncounterSettingsView(store: self.store)
                case .generateCombatantTraits:
                    if let store = store.scope(state: \.generateCombatantTraits, action: \.generateCombatantTraits) {
                        SheetNavigationContainer {
                            GenerateCombatantTraitsView(store: store)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func actionBar() -> some View {
        Group {
            if store.state.running == nil {
                if store.state.editMode == .active {
                    buildingEditModeActionBar()
                } else {
                    defaultActionBar()
                }
            } else {
                if store.state.editMode == .active {
                    runningEditModeActionBar()
                } else {
                    RunningEncounterActionBar(store: store)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .padding(8)
    }

    func defaultActionBar() -> some View {
        return RoundedButtonToolbar {
            if store.state.building.isScratchPad {
                Menu {
                    Button(action: {
                        store.send(.resetEncounter(false))
                    }) {
                        Text("Clear monsters").foregroundColor(Color.red)
                    }

                    Button(action: {
                        store.send(.resetEncounter(true))
                    }) {
                        Text("Clear all").foregroundColor(Color.red)
                    }
                } label: {
                    RoundedButtonLabel(maxHeight: .infinity) {
                        Label("Reset…", systemImage: "xmark.circle")
                            .accessibilityHint(Text("Activate to clear the encounter."))
                    }
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .disabled(store.state.building.combatants.isEmpty)
            }

            Menu {
                Button(action: {
                    store.send(
                        .setSheet(
                            .add(
                                EncounterDetailFeature.AddCombatantSheet(
                                    state: AddCombatantFeature.State(
                                        encounter:
                                            store.state.encounter)))))
                    store.send(.sheet(.presented(.add(.quickCreateAndDismissOnAdd))))
                }) {
                    Text("Quick create")
                    Image(systemName: "plus.circle")
                }
            } label: {
                RoundedButtonLabel(maxHeight: .infinity) {
                    Label("Add combatants", systemImage: "plus.circle")
                }
            } primaryAction: {
                if isUITesting || appNavigation == .tab {
                    store.send(
                        .setSheet(
                            .add(
                                EncounterDetailFeature.AddCombatantSheet(
                                    state: AddCombatantFeature.State(
                                        encounter: store.state.encounter)))))
                } else {
                    store.send(.showAddCombatantReferenceItem)
                }
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)

            if let resumables = store.state.resumableRunningEncounters.value, resumables.count > 0 {
                Menu {
                    Button(action: {
                        store.send(.run(nil), animation: .default)
                    }) {
                        Label("Start new run", systemImage: "plus.circle")
                    }

                    Divider()

                    ForEach(resumables, id: \.self) { r in
                        Button(action: {
                            store.send(.onResumeRunningEncounterTap(r), animation: .default)
                        }) {
                            Label(
                                "Resume run \(String(r.suffix(5)))",
                                systemImage: "play"
                            )
                        }
                    }
                } label: {
                    RoundedButtonLabel(maxHeight: .infinity) {
                        Label("Run encounter", systemImage: "play")
                    }
                } primaryAction: {
                    store.send(.run(nil), animation: .default)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .disabled(store.state.building.combatants.isEmpty)
            } else {
                Button(action: {
                    store.send(.run(nil), animation: .default)
                }) {
                    Label("Run encounter", systemImage: "play")
                }
                .disabled(store.state.building.combatants.isEmpty)
            }
        }
        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
    }

    func buildingEditModeActionBar() -> some View {
        return RoundedButtonToolbar {
            Button(action: {
                store.send(.selectionEncounterAction(.duplicate))
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .disabled(store.state.selection.isEmpty)

            Button(action: {
                store.send(.selectionEncounterAction(.remove))
            }) {
                Label("Remove", systemImage: "trash")
            }
            .disabled(store.state.selection.isEmpty)
        }
    }

    func runningEditModeActionBar() -> some View {
        RoundedButtonToolbar {
            Button(action: {
                store.send(.selectionCombatantAction(.hp(.current(.set(0)))))
            }) {
                Label("Eliminate", systemImage: "heart.slash")
            }
            .disabled(store.state.selection.isEmpty)

            Button(action: {
                let selection = store.state.selection.compactMap {
                    store.state.encounter.combatant(for: $0)
                }
                let state = CombatantTagsFeature.State(
                    combatants: selection,
                    effectContext: store.state.running.map {
                        EffectContext(
                            source: nil,
                            targets: selection,
                            running: $0
                        )
                    }
                )
                store.send(.setSheet(.selectedCombatantTags(state)))
            }) {
                Label("Tags...", systemImage: "tag")
            }
            .disabled(store.state.selection.isEmpty)

            Button(action: {
                store.send(.popover(.health(.selection)))
            }) {
                Label("Health...", systemImage: "suit.heart")
            }
            .disabled(store.state.selection.isEmpty)
        }
    }

    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {
                store.send(
                    .editMode(store.state.editMode.isEditing ? .inactive : .active),
                    animation: .default)
            }) {
                Text(store.state.editMode.isEditing ? "Done" : "Edit")
            }

            if store.state.running == nil {
                Menu {
                    if store.state.isMechMuseEnabled {
                        Button {
                            store.send(.onGenerateCombatantTraitsButtonTap)
                        } label: {
                            Label("Combatant Traits", systemImage: "quote.bubble")
                        }
                    }

                    Button {
                        store.send(.setSheet(.settings))
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                    Divider()

                    FeedbackMenuButton {
                        store.send(.onFeedbackButtonTap)
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var addCombatantOnSelection: (AddCombatantView.Action, Bool) -> Void {
        return { action, dismiss in
            switch action {
            case .add(let combatants):
                for c in combatants {
                    store.send(.encounter(.add(c)))
                }
            case .addByKey(let keys, let party):
                for key in keys {
                    store.send(.encounter(.addByKey(key, party)))
                }
            case .remove(let definitionID, let quantity):
                quantity.times {
                    if let combatant = store.state.encounter.combatants(with: definitionID).last {
                        store.send(.encounter(.remove(combatant)))
                    }
                }
            }

            if dismiss {
                store.send(.sheet(.dismiss))
            }
        }
    }

    var popover: Binding<AnyView?> {
        Binding<AnyView?>(
            get: {
                store.state.popover.flatMap { popover in
                    switch popover {
                    case .combatantInitiative(let combatant, _):
                        if store.combatantInitiativePopover != nil {
                            let popoverStore = store.scope(
                                state: \.combatantInitiativePopover!,
                                action: \.combatantInitiativePopover)
                            return NumberEntryPopover(store: popoverStore) { value in
                                self.store.send(
                                    .encounter(
                                        .combatant(
                                            .element(id: combatant.id, action: .initiative(value))))
                                )
                                self.store.send(.popover(nil))
                            }.eraseToAnyView
                        }
                        return nil
                    case .encounterInitiative:
                        return InitiativePopover { settings in
                            store.send(.encounter(.initiative(settings)))
                            store.send(.popover(nil))
                        }.makeBody()
                    case .health(let target):
                        return HealthDialog(hp: nil) { action in
                            switch target {
                            case .single(let combatant):
                                store.send(
                                    .encounter(
                                        .combatant(.element(id: combatant.id, action: action))))
                            case .selection:
                                store.send(.selectionCombatantAction(action))
                            }
                            store.send(.popover(nil))
                        }.eraseToAnyView
                    }
                }
            },
            set: {
                if $0 == nil {
                    store.send(.popover(nil))
                }
            }
        )
    }
}

struct CombatantSection: View {
    let store: StoreOf<EncounterDetailFeature>
    let appNavigation: AppNavigation
    let title: String
    let encounter: Encounter
    let running: RunningEncounter?
    let combatants: [Combatant]

    var body: some View {
        Section(
            header: Group {
                HStack {
                    if store.state.editMode == .active {
                        with(Set(store.state.encounter.combatants.map { $0.id })) { allIds in
                            with(store.state.selection == allIds) { selectedAll in
                                Button(action: {
                                    if selectedAll {
                                        store.send(.selection(Set()))
                                    } else {
                                        store.send(.selection(allIds))
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
            },
            footer: Group {
                EmptyView()  // TODO
            }
        ) {
            ForEach(combatants, id: \.id) { combatant in
                CombatantRow(
                    encounter: self.encounter, running: self.running, combatant: combatant,
                    onHealthTap: {
                        store.send(.popover(.health(.single(combatant))))
                    },
                    onInitiativeTap: {
                        store.send(
                            .popover(
                                .combatantInitiative(
                                    combatant,
                                    NumberEntryFeature.State.initiative(combatant: combatant))),
                            animation: .default)
                    }
                )
                .accentColor(Color.primary)
                // contentShape is needed or else the tapGesture on the whole cell doesn't work
                // scale is used to make the row easier selectable in edit mode
                .contentShape(Rectangle().scale(store.state.editMode.isEditing ? 0 : 1))
                .onTapGesture {
                    if appNavigation == .tab {
                        store.send(
                            .setSheet(
                                .combatant(
                                    CombatantDetailFeature.State(
                                        runningEncounter: store.state.running, combatant: combatant)
                                )))
                    } else {
                        store.send(.showCombatantDetailReferenceItem(combatant))
                    }
                }
                // Using a menu (instead of a contextMenu) here would be nice, but it blocks interaction with the row's content
                .contextMenu {
                    Button(action: {
                        store.send(.encounter(.remove(combatant)))
                    }) {
                        Text("Remove")
                        Image(systemName: "trash")
                    }

                    if !combatant.definition.isUnique {
                        Button(action: {
                            store.send(.encounter(.duplicate(combatant)))
                        }) {
                            Text("Duplicate")
                            Image(systemName: "plus.square.on.square")
                        }
                    }

                    if !combatant.isDead {
                        Button(action: {
                            store.send(
                                .encounter(
                                    .combatant(
                                        .element(id: combatant.id, action: .hp(.current(.set(0))))))
                            )
                        }) {
                            Text("Eliminate")
                            Image(systemName: "heart.slash")
                        }
                    }

                    Button(action: {
                        store.send(
                            .encounter(
                                .combatant(
                                    .element(
                                        id: combatant.id,
                                        action: .reset(
                                            hp: true, initiative: true, resources: true, tags: true)
                                    ))))
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
            store.send(.encounter(.remove(combatants[i])))
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

extension EncounterDetailFeature.State {
    var shouldShowEncounterDifficulty: Bool {
        running == nil
            && !encounter.combatants.isEmpty
    }
}
