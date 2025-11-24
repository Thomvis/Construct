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

    var store: StoreOf<HealthDialogFeature>
    @ObservedObject var viewStore: ViewStoreOf<HealthDialogFeature>
    let onOutcomeSelected: (Hp.Action) -> Void

    var outcome: Int {
        viewStore.state.numberEntryView.value ?? 0
    }

    var body: some View {
        VStack {
            NumberEntryView(store: store.scope(state: \.numberEntryView, action: \.numberEntryView))
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

struct HealthDialogFeature: Reducer {
    struct State: Equatable {
        var numberEntryView: NumberEntryFeature.State
        var hp: Hp?
    }

    @CasePathable
    enum Action: Equatable {
        case numberEntryView(NumberEntryFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.numberEntryView, action: \.numberEntryView) {
            NumberEntryFeature()
        }
    }
}

extension HealthDialog: Popover {

    func makeBody() -> AnyView {
        eraseToAnyView
    }

    init(hp: Hp?, onCombatantAction: @escaping (CombatantAction) -> ()) {
        self.init(
            store: Store(
                initialState: HealthDialogFeature.State(numberEntryView: .pad(value: 0), hp: hp)
            ) {
                HealthDialogFeature()
            },
            onCombatantAction: onCombatantAction
        )
    }

    init(store: Store<HealthDialogFeature.State, HealthDialogFeature.Action>, onCombatantAction: @escaping (CombatantAction) -> ()) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
        self.onOutcomeSelected = { a in
            onCombatantAction(.hp(a))
        }
    }
}

extension HealthDialogFeature.State {
    static let nullInstance = HealthDialogFeature.State(numberEntryView: NumberEntryFeature.State.nullInstance, hp: nil)
}
