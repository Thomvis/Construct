//
//  HealthDialog.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 06/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct HealthDialog: View {
    var popoverId: AnyHashable { "HealthDialog" } // fine unless a view tries to replace one health dialog with another

    var store: Store<HealthDialogState, HealthDialogAction>
    @ObservedObject var viewStore: ViewStore<HealthDialogState, HealthDialogAction>
    let onOutcomeSelected: (UserAction, Int) -> Void

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
                    self.onOutcomeSelected(.hit, self.outcome)
                }) {
                    HStack {
                        Image(systemName: "shield.lefthalf.fill")
                        Text(hitButtonLabel)
                    }
                }.disabled(outcome == 0)
                Spacer()
                SwiftUI.Button(action: {
                    self.onOutcomeSelected(.heal, self.outcome)
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text(healButtonLabel)
                    }
                }.disabled(outcome == 0)
                Spacer()
                SwiftUI.Button(action: {
                    self.onOutcomeSelected(.other, self.outcome)
                }) {
                    HStack {
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

    enum UserAction {
        case hit
        case heal
        case other
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

    init(environment: Environment, hp: Hp?, onCombatantAction: @escaping (CombatantAction) -> (), onOtherAction: @escaping (Int) -> Void) {
        self.init(
            store: Store(
                initialState: HealthDialogState(numberEntryView: .pad(value: 0), hp: hp),
                reducer: HealthDialogState.reducer,
                environment: environment
            ),
            onCombatantAction: onCombatantAction,
            onOtherAction: onOtherAction
        )
    }

    init(store: Store<HealthDialogState, HealthDialogAction>, onCombatantAction: @escaping (CombatantAction) -> (), onOtherAction: @escaping (Int) -> Void) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.onOutcomeSelected = { a, p in
            switch a {
            case .hit:
                withAnimation {
                    onCombatantAction(.dealDamage(p))
                }
            case .heal:
                withAnimation {
                    onCombatantAction(.heal(p))
                }
            case .other:
                onOtherAction(p)
            }
        }
    }

    static func otherActionSheet(combatant: Combatant?, value: Int) -> ActionSheetState<CombatantAction> {
        let title = combatant.map { "Edit \($0.name)'s hit points" } ?? "Edit hit points"
        return ActionSheetState(title: TextState(title), buttons: [
            .default(TextState("Add \(value) temporary hp"), send: .hp(.temporary(.add(value)))),
            .default(TextState("Set current hp to \(value)"), send: .hp(.current(.set(value)))),
            .cancel()
        ])
    }
}

extension HealthDialogState {
    static let reducer: Reducer<Self, HealthDialogAction, Environment> = NumberEntryViewState.reducer.pullback(state: \.numberEntryView, action: /HealthDialogAction.numberEntryView)
}

extension HealthDialogState {
    static let nullInstance = HealthDialogState(numberEntryView: NumberEntryViewState.nullInstance, hp: nil)
}
