//
//  HealthDialog.swift
//  Construct
//
//  Created by Thomas Visser on 06/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import GameModels

struct HealthDialog: View {
    var popoverId: AnyHashable { "HealthDialog" } // fine unless a view tries to replace one health dialog with another

    var store: Store<HealthDialogState, HealthDialogAction>
    @ObservedObject var viewStore: ViewStore<HealthDialogState, HealthDialogAction>
    let onOutcomeSelected: (Hp.Action) -> Void

    var outcome: Int {
        viewStore.state.numberEntryView.value ?? 0
    }

    var body: some View {
        VStack {
            NumberEntryView(store: store.scope(state: { $0.numberEntryView }, action: { .numberEntryView($0) }))
            Divider()
            HStack {
                Spacer()
                SwiftUI.Button(action: {
                    self.onOutcomeSelected(.current(.add(-self.outcome)))
                }) {
                    HStack {
                        Image(systemName: "shield.lefthalf.fill")
                        Text(hitButtonLabel)
                    }
                }.disabled(outcome == 0)
                Spacer()
                SwiftUI.Button(action: {
                    self.onOutcomeSelected(.current(.add(self.outcome)))
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text(healButtonLabel)
                    }
                }.disabled(outcome == 0)
                Spacer()

                Menu(content: {
                    Button(action: {
                        self.onOutcomeSelected(.current(.set(self.outcome)))
                    }) {
                        Text("Set current hp to \(self.outcome)")
                    }

                    Button(action: {
                        self.onOutcomeSelected(.temporary(.set(self.outcome)))
                    }) {
                        Text("Set temporary hp to \(self.outcome)")
                    }
                }) {
                    SwiftUI.Button(action: { }) {
                        Text("Other...")
                    }
                }

                Spacer()
            }
        }
    }

    var hitButtonLabel: String {
        if var hp = viewStore.state.hp, self.outcome > 0, hp.effective > 0 {
            hp.hit(self.outcome)
            if hp.unboundedEffective == 0 {
                return "Hit (dead)"
            } else if hp.unboundedEffective < 0 {
                return "Hit (dead - \(hp.unboundedEffective * -1))"
            }
        }
        return "Hit"
    }

    var healButtonLabel: String {
        if let hp = viewStore.state.hp, self.outcome > 0, hp.effective < hp.maximum {
            if hp.current + self.outcome >= hp.maximum {
                return "Heal (full)"
            }
        }
        return "Heal"
    }
}

struct HealthDialogState: Equatable {
    var numberEntryView: NumberEntryViewState
    var hp: Hp?
}

enum HealthDialogAction: Equatable {
    case numberEntryView(NumberEntryViewAction)
}

extension HealthDialog: Popover {

    func makeBody() -> AnyView {
        eraseToAnyView
    }

    init(environment: Environment, hp: Hp?, onCombatantAction: @escaping (CombatantAction) -> ()) {
        self.init(
            store: Store(
                initialState: HealthDialogState(numberEntryView: .pad(value: 0), hp: hp),
                reducer: HealthDialogState.reducer,
                environment: environment
            ),
            onCombatantAction: onCombatantAction
        )
    }

    init(store: Store<HealthDialogState, HealthDialogAction>, onCombatantAction: @escaping (CombatantAction) -> ()) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.onOutcomeSelected = { a in
            onCombatantAction(.hp(a))
        }
    }
}

extension HealthDialogState {
    static let reducer: Reducer<Self, HealthDialogAction, Environment> = NumberEntryViewState.reducer.pullback(state: \.numberEntryView, action: /HealthDialogAction.numberEntryView, environment: { $0 })
}

extension HealthDialogState {
    static let nullInstance = HealthDialogState(numberEntryView: NumberEntryViewState.nullInstance, hp: nil)
}
