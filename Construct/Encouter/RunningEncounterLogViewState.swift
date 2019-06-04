//
//  RunningEncounterLogViewState.swift
//  Construct
//
//  Created by Thomas Visser on 28/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

struct RunningEncounterLogViewState: Equatable {
    var encounter: RunningEncounter
    var context: Combatant?

    var events: [RunningEncounterEvent] {
        if let c = context {
            return encounter.log.reversed().filter { $0.involves(c) }
        } else {
            return encounter.log.reversed()
        }
    }
}

extension RunningEncounterLogViewState: NavigationStackItemState {
    var navigationStackItemStateId: String {
        "RunningEncounterLogViewState"
    }

    var navigationTitle: String { "Running Encounter Log" }
}

extension RunningEncounterLogViewState {
    static let nullInstance = RunningEncounterLogViewState(encounter: RunningEncounter.nullInstance, context: nil)
}
