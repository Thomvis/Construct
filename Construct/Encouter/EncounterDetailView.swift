//
//  EncounterDetailView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 06/06/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct EncounterDetailView: View {
    @EnvironmentObject var environment: Environment
    var store: Store<EncounterDetailViewState, EncounterDetailViewState.Action>
    @ObservedObject var viewStore: ViewStore<EncounterDetailViewState, EncounterDetailViewState.Action>

    init(store: Store<EncounterDetailViewState, EncounterDetailViewState.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.normalizedForDeduplication == $1.normalizedForDeduplication })
    }

    var encounter: Encounter {
        viewStore.state.encounter
    }

    var body: some View {
        return ZStack {
            List(selection: Binding(get: {
                self.viewStore.state.selection
            }, set: {
                self.viewStore.send(.selection($0))
            })) {
                if viewStore.state.shouldShowEncounterDifficulty {
                    Section(header: EmptyView().accessibilityHidden(true)) {
                        SimpleButton(action: {
                            self.viewStore.send(.sheet(.settings))
                        }) {
                            EncounterDifficultyView(difficulty: EncounterDifficulty(
                                party: encounter.partyEntriesForDifficulty,
                                monsters: encounter.combatants.compactMap { $0.definition.stats?.challengeRating }
                            ))
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
                    CombatantSection(parent: self, title: "Combatants", encounter: viewStore.state.encounter, running: viewStore.state.running, combatants: viewStore.state.encounter.combatantsInDisplayOrder)
                }

                // Adds padding for the bottom action bar
                Section {
                    EmptyView().padding(.bottom, 80)
                }
            }
            .listStyle(GroupedListStyle())
            .environment(\.editMode, Binding(get: {
                self.viewStore.state.editMode ? .active : .inactive
            }, set: {
                self.viewStore.send(.editMode($0.isEditing))
            }))

            VStack {
                if viewStore.state.running == nil {
                    if viewStore.state.editMode {
                        buildingEditModeActionBar()
                    } else {
                        defaultActionBar()
                    }
                } else {
                    if viewStore.state.editMode {
                        runningEditModeActionBar()
                    } else {
                        RunningEncounterActionBar(viewStore: viewStore)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
        }
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            withAnimation {
                self.viewStore.send(.editMode(!self.viewStore.state.editMode))
            }
        }) {
            Text(self.viewStore.state.editMode ? "Done" : "Edit")
        })
        .sheet(item: viewStore.binding(get: \.sheet) { _ in .sheet(nil) }, onDismiss: {
            self.viewStore.send(.sheet(nil))
        }, content: self.sheetView)
        .actionSheet(store.scope(state: { $0.actionSheet }), dismiss: .actionSheet(nil))
        .popover(popover)
        .onAppear {
            self.viewStore.send(.onAppear)
        }
    }

    func defaultActionBar() -> some View {
        return HStack {
            if viewStore.state.building.isScratchPad {
                RoundedButton(action: {
                    self.viewStore.send(.actionSheet(.reset))
                }) {
                    Label("Reset...", systemImage: "xmark.circle")
                }.disabled(self.viewStore.state.building.combatants.isEmpty)
            }

            RoundedButton(action: {
                self.viewStore.send(.sheet(.add(AddCombatantSheet(state: AddCombatantState(encounter: self.viewStore.state.encounter)))))
            }) {
                Label("Add combatants", systemImage: "plus.circle")
            }
            .contextMenu {
                Button(action: {
                    self.viewStore.send(.sheet(.add(AddCombatantSheet(state: AddCombatantState(encounter:
                        self.viewStore.state.encounter)))))
                    self.viewStore.send(.addCombatant(.quickCreate))
                }) {
                    Text("Quick create")
                    Image(systemName: "plus.circle")
                }
            }

            RoundedButton(action: {
                self.viewStore.send(.onRunEncounterTap)
            }) {
                Label("Run encounter", systemImage: "play")
            }.disabled(self.viewStore.state.building.combatants.isEmpty)
        }
        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
    }

    func buildingEditModeActionBar() -> some View {
        return HStack {
            RoundedButton(action: {
                self.viewStore.send(.sheet(.settings))
            }) {
                Label("Settings", systemImage: "gear")
            }

            RoundedButton(action: {
                self.viewStore.send(.selectionEncounterAction(.duplicate))
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .disabled(viewStore.state.selection.isEmpty)

            RoundedButton(action: {
                self.viewStore.send(.selectionEncounterAction(.remove))
            }) {
                Label("Remove", systemImage: "trash")
            }
            .disabled(viewStore.state.selection.isEmpty)
        }
    }

    func runningEditModeActionBar() -> some View {
        return HStack {
            RoundedButton(action: {
                self.viewStore.send(.selectionCombatantAction(.hp(.current(.set(0)))))
            }) {
                Label("Eliminate", systemImage: "heart.slash")
            }
            .disabled(viewStore.state.selection.isEmpty)

            RoundedButton(action: {
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

            RoundedButton(action: {
                self.viewStore.send(.popover(.health(.selection)))
            }) {
                Label("Health...", systemImage: "suit.heart")
            }
            .disabled(viewStore.state.selection.isEmpty)
        }
    }

    func sheetView(_ sheet: EncounterDetailViewState.Sheet) -> some View {
        switch sheet {
        case .add:
            return IfLetStore(store.scope(state: { $0.addCombatantState }, action: { .addCombatant($0) })) { store in
                AddCombatantView(store: store) { action, dismiss in
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
                }.environmentObject(self.environment)
            }.eraseToAnyView
        case .combatant:
            return IfLetStore(store.scope(state: { $0.combatantDetailState }, action: { .combatantDetail($0) })) { store in
                CombatantDetailContainerView(store: store).environmentObject(self.environment)
            }.eraseToAnyView
        case .runningEncounterLog:
            return IfLetStore(store.scope(state: { $0.runningEncounterLogState }, action: { fatalError() })) { store in
                SheetNavigationContainer {
                    RunningEncounterLogView(store: store).environmentObject(self.environment)
                }
            }.eraseToAnyView
        case .selectedCombatantTags:
            return IfLetStore(store.scope(state: { $0.selectedCombatantTagsState }, action: { .selectedCombatantTags($0) })) { store in
                SheetNavigationContainer {
                    CombatantTagsView(store: store)
                }.environmentObject(self.environment)
            }.eraseToAnyView
        case .settings:
            return EncounterSettingsView(store: self.store).environmentObject(self.environment).eraseToAnyView
        }
    }

    var popover: Binding<Popover?> {
        Binding(get: {
            guard let popover = viewStore.popover else { return nil }
            switch popover {
            case .combatantInitiative(let combatant):
                return NumberEntryPopover.initiative(environment: environment, combatant: combatant) { value in
                    viewStore.send(.encounter(.combatant(combatant.id, .initiative(value))))
                    viewStore.send(.popover(nil))
                }
            case .encounterInitiative:
                return InitiativePopover { settings in
                    viewStore.send(.encounter(.initiative(settings)))
                    viewStore.send(.popover(nil))
                }
            case .health(let target):
                return HealthDialog(environment: environment, hp: nil) { action in
                    switch target {
                    case .single(let combatant):
                        viewStore.send(.encounter(.combatant(combatant.id, action)))
                    case .selection:
                        viewStore.send(.selectionCombatantAction(action))
                    }
                    viewStore.send(.popover(nil))
                } onOtherAction: { value in
                    viewStore.send(.actionSheet(.otherHpActions(value, target: target)))
                    viewStore.send(.popover(nil))
                }
            }
        }, set: {
            if $0 == nil {
                viewStore.send(.popover(nil))
            }
        })
    }
}

extension ActionSheetState where Action == EncounterDetailViewState.Action {
    static func otherHpActions(_ value: Int, target: EncounterDetailViewState.CombatantActionTarget) -> Self {
        switch target {
        case .single(let combatant):
            return HealthDialog.otherActionSheet(combatant: combatant, value: value).pullback {
                EncounterDetailViewState.Action.encounter(.combatant(combatant.id, $0))
            }
        case .selection:
            return HealthDialog.otherActionSheet(combatant: nil, value: value)
                .pullback(toGlobalAction: /EncounterDetailViewState.Action.selectionCombatantAction)
        }
    }

    static func runEncounter(_ resumables: [KeyValueStore.Record]) -> Self {
        let formatter = RelativeDateTimeFormatter()

        let resumeButtons: [Button] = resumables.map { r -> Button in
            let relativeDate = formatter.localizedString(for: r.modifiedAt, relativeTo: Date())
            return .default("Resume run from \(relativeDate)", send: .onResumeRunningEncounterTap(r.key)) // used to be wrapped in withAnimation
        }

        return ActionSheetState(
            title: "Run encounter",
            buttons: resumeButtons + [
                .default("Start new run", send: .run(nil)),
                .cancel(send: .actionSheet(nil))
            ]
        )
    }

    static let reset: Self = ActionSheetState(
        title: "Reset encounter",
        buttons: [
            .destructive("Clear monsters", send: .resetEncounter(false)),
            .destructive("Clear all", send: .resetEncounter(true)),
            .cancel(send: .actionSheet(nil))
        ]
    )
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
                if parent.viewStore.state.editMode {
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
                    withAnimation {
                        self.parent.viewStore.send(.popover(.combatantInitiative(combatant)))
                    }
                })
                // contentShape is needed or else the tapGesture on the whole cell doesn't work
                // scale is used to make the row easier selectable in edit mode
                .contentShape(Rectangle().scale(self.parent.viewStore.state.editMode ? 0 : 1))
                .onTapGesture {
                    self.parent.viewStore.send(.sheet(.combatant(CombatantDetailViewState(runningEncounter: self.parent.viewStore.state.running, encounter: self.parent.viewStore.state.encounter, combatant: combatant))))
                }
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

extension EncounterDetailViewState.Sheet: Identifiable {
    static let settingsUUID = UUID()

    var id: UUID {
        switch self {
        case .add(let s): return s.id
        case .combatant(let s): return s.combatant.id
        case .runningEncounterLog(let s): return s.encounter.id
        case .selectedCombatantTags: return UUID(uuidString: "FA34879F-C2AB-4B0C-A281-50404D56118C")!
        case .settings: return Self.settingsUUID
        }
    }
}

extension EncounterDetailViewState {
    var shouldShowEncounterDifficulty: Bool {
        running == nil
            && !encounter.combatants.isEmpty
    }
}
