//
//  EncounterDetailTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 18/06/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import XCTest
@testable import Construct
import Helpers
import GameModels

class EncounterDetailTest: XCTestCase {

    @MainActor
    func testFlow_RemoveActiveCombatant() async throws {
        let combatant1 = Combatant(adHoc: AdHocCombatantDefinition(
            id: UUID().tagged(),
            stats: apply(StatBlock.default) {
                $0.initiative = Initiative(modifier: .init(modifier: 1), advantage: false)
            }))
        let combatant2 = Combatant(adHoc: AdHocCombatantDefinition(
            id: UUID().tagged(),
            stats: apply(StatBlock.default) {
                $0.initiative = Initiative(modifier: .init(modifier: 1), advantage: false)
            }))

        let initialState = EncounterDetailFeature.State(building: Encounter(name: "", combatants: [
            combatant1,
            combatant2,
        ]))

        let uuidGenerator = UUIDGenerator.fake()

        let store = TestStore(
            initialState: initialState
        ) {
            EncounterDetailFeature()
        } withDependencies: {
            $0.uuid = uuidGenerator
            $0.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
        }
        store.exhaustivity = .off

        // start encounter
        await store.send(.run(nil))

        // roll initiative (results are random, so we don't assert on specific values)
        await store.send(.runningEncounter(.current(.initiative(InitiativeSettings.default))))

        // Get the current state to know which combatant has the turn
        let stateAfterInitiative = store.state
        guard let running = stateAfterInitiative.running,
              let turn = running.turn else {
            XCTFail("Expected running encounter with turn")
            return
        }

        // remove the combatant who has the current turn
        let activeCombatant = running.current.combatants.first { $0.id == turn.combatantId }!
        await store.send(.runningEncounter(.current(.remove(activeCombatant)))) {
            $0.running!.current.combatants.removeAll { $0.id == activeCombatant.id }
            // Turn should advance to the remaining combatant
            let remainingCombatant = $0.running!.current.combatants.first!
            $0.running!.turn = .init(round: 1, combatantId: remainingCombatant.id)
        }
    }

}
