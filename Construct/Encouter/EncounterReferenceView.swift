//
//  EncounterReferenceView.swift
//  Construct
//
//  Created by Thomas Visser on 25/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct EncounterReferenceView: View {

    let store: Store<ReferenceViewState, EncounterReferenceViewAction>

    var body: some View {
        ReferenceView(store: store.scope(state: { $0 }, action: { .reference($0) }))
    }
}

enum EncounterReferenceViewAction: Equatable {
    case reference(ReferenceViewAction)
}

let encounterReferenceReducer: Reducer<ReferenceViewState, EncounterReferenceViewAction, Environment> = Reducer.combine(
    ReferenceViewState.reducer.pullback(state: \.self, action: /EncounterReferenceViewAction.reference)
)

extension ReferenceViewState {

    init(encounter: Encounter, selectedCombatantId: UUID, runningEncounter: RunningEncounter?) {
        let itemState = ReferenceItemViewState(content: .combatantDetail(ReferenceItemViewState.Content.CombatantDetail(
            encounter: encounter,
            selectedCombatantId: selectedCombatantId,
            runningEncounter: runningEncounter
        )))
        self.init(items: [.init(state: itemState)], selectedItemId: nil)
    }

    mutating func updateEncounter(_ encounter: Encounter) {
        fatalError()
    }

    mutating func updateRunningEncounter(_ encounter: RunningEncounter?) {
        fatalError()
    }
}
