//
//  AddCombatantReferenceItemView.swift
//  Construct
//
//  Created by Thomas Visser on 26/02/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct AddCombatantReferenceItemView: View {
    let store: Store<ReferenceItem.State.Content.AddCombatant, ReferenceItem.Action.AddCombatant>

    var body: some View {
        AddCombatantView(
            store: store.scope(state: { $0.addCombatantState }, action: { .addCombatant($0) }),
            externalNavigation: true,
            showEncounterDifficulty: false,
            onSelection: { action, _ in
                store.send(.onSelection(action))
            }
        )
    }
}
