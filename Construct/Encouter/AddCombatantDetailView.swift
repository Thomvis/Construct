//
//  AddCombatantDetailView.swift
//  Construct
//
//  Created by Thomas Visser on 02/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct AddCombatantDetailView: View {
    @EnvironmentObject var env: Environment
    var parentStore: Store<AddCombatantState, AddCombatantState.Action>
    @ObservedObject var parentViewStore: ViewStore<AddCombatantState, AddCombatantState.Action>
    var store: Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>
    @ObservedObject var viewStore: ViewStore<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>

    let onSelection: (AddCombatantView.Action) -> Void

    init(parentStore: Store<AddCombatantState, AddCombatantState.Action>, store: Store<CompendiumEntryDetailViewState, CompendiumItemDetailViewAction>, onSelection: @escaping (AddCombatantView.Action) -> Void) {
        self.parentStore = parentStore
        self.parentViewStore = ViewStore(parentStore)
        self.store = store
        self.viewStore = ViewStore(store)
        self.onSelection = onSelection
    }

    @State var amount: Int?
    var effectiveAmount: Binding<Int> {
        Binding(get: {
            if let monster = self.monster {
                return self.amount ?? self.parentViewStore.state.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: monster)]?.count ?? 1
            } else {
                return self.amount ?? 1
            }
        }, set: {
            self.amount = $0
        })
    }

    @State var rollForHp = false
    @State var popover: Store<NumberEntryViewState, NumberEntryViewAction>? // fixme: should be part of the view state

    var monster: Monster? {
        viewStore.state.item as? Monster
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionContainer(title: "Encounter") {
                    VStack {
                        HStack {
                            Stepper("Quantity: \(effectiveAmount.wrappedValue)", value: effectiveAmount, in: 0...100)
                            Button(action: {
                                self.popover = Store(
                                    initialState: NumberEntryViewState.dice(.editingExpression()),
                                    reducer: NumberEntryViewState.reducer,
                                    environment: env
                                )
                            }) {
                                Text("Roll")
                            }
                        }

                        Picker(selection: $rollForHp, label: Text("HP")) {
                            Text("Use static HP").tag(false)
                            Text("Roll for HP").tag(true)
                        }.pickerStyle(SegmentedPickerStyle()).disabled(combatantQuantityDifference <= 0)

                        Divider().padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                        ActivityButton(
                            normal: Text(confirmText).frame(width: 200).animation(nil, value: self.combatantQuantityDifference),
                            confirmation: HStack {
                                Image(systemName: "checkmark")
                                Text("Done")
                            }.frame(width: 200),
                            action: self.onConfirmTapped
                        )
                        .disabled(combatantQuantityDifference == 0)
                    }
                }

                monster.map { monster in
                    SectionContainer(title: "Stats") {
                        StatBlockView(stats: monster.stats).disabled(true)
                    }
                    .padding(.bottom, 80)
                }
            }
            .padding(12)
        }
        .popover(Binding(get: {
            self.popover.map {
                NumberEntryPopover(store: $0) { result in
                    self.amount = result
                    self.popover = nil
                }.eraseToAnyView
            }
        }, set: {
            if $0 == nil {
                self.popover = nil
            }
        }))
    }

    var combatantQuantityDifference: Int {
        guard let monster = monster else { return 0 }
        let combatantsInEncounterCount: Int = parentViewStore.state.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: monster)]?.count ?? 0

        return effectiveAmount.wrappedValue - combatantsInEncounterCount
    }

    var confirmText: String {
        let diff = combatantQuantityDifference
        if diff >= 0 {
            return "Add \(diff)"
        } else {
            return "Remove \(diff * -1)"
        }
    }

    func onConfirmTapped() {
        guard let monster = monster else { return }

        let diff = combatantQuantityDifference
        if diff > 0 {
            let combatants = (0..<diff).map { _ in
                Combatant(
                    monster: monster,
                    hp: rollForHp ? monster.stats.hitPointDice.map { Hp(fullHealth: $0.roll.total) } : nil
                )
            }
            onSelection(.add(combatants))
        } else {
            onSelection(.remove(CompendiumCombatantDefinition.definitionID(for: monster), diff * -1))
        }
    }
}
