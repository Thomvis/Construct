//
//  EncounterSettingsView.swift
//  Construct
//
//  Created by Thomas Visser on 27/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import GameModels
import Persistence

struct EncounterSettingsView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: Store<EncounterDetailFeature.State, EncounterDetailFeature.Action>
    @ObservedObject var viewStore: ViewStore<EncounterDetailFeature.State, EncounterDetailFeature.Action>

    @State var popover: Popover?

    // Provide a stable date for the duration of this screen
    @State var now = Date()

    init(store: Store<EncounterDetailFeature.State, EncounterDetailFeature.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
    }

    var encounter: Encounter {
        viewStore.state.building
    }

    var party: Binding<Encounter.Party> {
        Binding(get: {
            self.viewStore.state.building.partyWithEntriesForDifficulty.0
        }) {
            self.viewStore.send(.buildingEncounter(.partyForDifficulty($0)))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Calculate Difficulty"), footer: Button(action: {
                    if self.party.wrappedValue.simplePartyEntries == nil {
                        self.party.wrappedValue.simplePartyEntries = [Encounter.Party.SimplePartyEntry(level: 2, count: 2)]
                    } else {
                        self.party.wrappedValue.simplePartyEntries?.append(Encounter.Party.SimplePartyEntry(level: 2, count: 2))
                    }
                }) {
                    if !self.party.wrappedValue.combatantBased {
                        Image(systemName: "plus.circle").font(Font.footnote.bold())
                        Text("Add different level PCs").bold()
                    }
                }) {
                    Picker(selection: self.party.combatantBased, label: Text("Party")) {
                        Text("By level").tag(false)
                        Text("Select combatants").tag(true)
                    }.pickerStyle(SegmentedPickerStyle())

                    if !party.wrappedValue.combatantBased {
                        ForEach(party.wrappedValue.simplePartyEntries ?? []) { l in
                            HStack {
                                Text("\(l.count)").bold() + Text(" level ") + Text("\(l.level)").bold() + Text(" characters")
                                Spacer()
                                Button(action: {
                                    self.popover = SimplePartyEntryEditPopover(entry: l) { changedEntry in
                                        self.popover = nil
                                        self.party.wrappedValue.simplePartyEntries?[id: l.id] = changedEntry
                                    }
                                }) {
                                    Text("Change")
                                }
                            }.deleteDisabled(self.party.wrappedValue.simplePartyEntries.map { $0.count == 1 } ?? true)
                        }
                        .onDelete { indices in
                            for i in indices {
                                self.party.wrappedValue.simplePartyEntries?.remove(at: i)
                            }
                        }
                    } else {
                        if encounter.playerControlledCombatants.isEmpty {
                            Text("No player characters found in the encounter")
                        } else {
                            ForEach(encounter.playerControlledCombatants, id: \.id) { combatant in
                                HStack {
                                    Checkbox(selected: self.isCombatantInParty(combatant))
                                    Text("\(combatant.name) (\(combatant.levelText))")
                                        .opacity(self.canSelectCombatant(combatant) ? 1.0 : 0.33)
                                }.onTapGesture {
                                    self.toggleCombatantInParty(combatant)
                                }.disabled(!self.canSelectCombatant(combatant))
                            }
                            HStack {
                                Checkbox(selected: !hasCombatantPartyFilter)
                                Text("All player characters")
                            }.onTapGesture {
                                self.toggleCombatantPartyFilter()
                            }
                        }
                    }
                }

                Section(header: Text("Saved runs")) {
                    if (viewStore.state.resumableRunningEncounters.value ?? []).isEmpty {
                        Text("No runs found")
                    } else {
                        ForEach(viewStore.state.resumableRunningEncounters.value ?? [], id: \.self) { run in
                            Text(self.titleForRawRunningEncounter(run)).lineLimit(1)
                        }.onDelete(perform: self.onDeleteResumableRunningEncounter)
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done").bold()
            })
        }
        .popover($popover)
    }

    func canSelectCombatant(_ c: Combatant) -> Bool {
        c.definition.level != nil
    }

    func isCombatantInParty(_ c: Combatant) -> Bool {
        guard let party = party.wrappedValue.combatantParty else { return false }
        guard let filter = party.filter else { return canSelectCombatant(c) }
        return filter.contains(c.id)
    }

    func toggleCombatantInParty(_ c: Combatant) {
        guard let party = self.party.wrappedValue.combatantParty else {
            // first selected combatant
            self.party.wrappedValue.combatantParty = Encounter.Party.CombatantParty(filter: [c.id])
            return
        }

        if let filter = party.filter {
            if let idx = filter.firstIndex(of: c.id) {
                // combatant was in filter, remove
                self.party.wrappedValue.combatantParty?.filter?.remove(at: idx)
            } else {
                // combatant wasn't in filter, add
                self.party.wrappedValue.combatantParty?.filter?.append(c.id)
            }
        } else {
            // party didn't have a filter, select all exect this combatant
            self.party.wrappedValue.combatantParty?.filter = self.encounter.playerControlledCombatants
                .filter { $0.id != c.id && self.canSelectCombatant($0) }
                .map { $0.id }
        }
    }

    var hasCombatantPartyFilter: Bool {
        guard let party = party.wrappedValue.combatantParty else { return false }
        return party.filter != nil
    }

    func toggleCombatantPartyFilter() {
        if hasCombatantPartyFilter {
            party.wrappedValue.combatantParty?.filter = nil
        } else {
            party.wrappedValue.combatantParty?.filter = []
        }
    }

    func titleForRawRunningEncounter(_ key: String) -> String {
//        let formatter = RelativeDateTimeFormatter()
//        let relativeDate = formatter.localizedString(for: record.modifiedAt, relativeTo: self.now)
        return "Run \(key.suffix(5))"
    }

    func onDeleteResumableRunningEncounter(_ indices: IndexSet) {
        let keys = indices.compactMap { viewStore.state.resumableRunningEncounters.value?[$0] }
        for key in keys {
            viewStore.send(.removeResumableRunningEncounter(key))
        }
    }

}

fileprivate extension Combatant {
    var levelText: String {
        definition.level.map { "level \($0)" } ?? "No level set"
    }
}

struct SimplePartyEntryEditPopover: View, Popover {
    var popoverId: AnyHashable { "SimplePartyEntryEditPopover" }

    @State var entry: Encounter.Party.SimplePartyEntry
    var onSelection: (Encounter.Party.SimplePartyEntry) -> Void

    func makeBody() -> AnyView {
        self.eraseToAnyView
    }

    var body: some View {
        VStack {
            Stepper(value: $entry.count, in: 1...20) {
                Text("Count: \(entry.count)").font(.headline)
            }

            Stepper(value: $entry.level, in: 1...20) {
                Text("Level: \(entry.level)").font(.headline)
            }

            Divider()

            Button(action: {
                self.onSelection(self.entry)
            }) {
                Text("Done")
            }
        }
    }
}
