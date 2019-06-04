//
//  RunningEncounterTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 23/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class RunningEncounterTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testNextTurn() {
        var sut = encounter1

        sut.nextTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[1].id))
        sut.nextTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[2].id))
        sut.nextTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 2, combatantId: sut.current.combatants[0].id))
    }

    func testPreviousTurn() {
        var sut = encounter1

        sut.nextTurn()
        sut.nextTurn()
        sut.nextTurn()

        sut.previousTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[2].id))
        sut.previousTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[1].id))
        sut.previousTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id))
        sut.previousTurn()
        XCTAssertEqual(sut.turn, RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id))
    }

    func testTagExpiryDurationUntilEndOfTargetTurn() {
        var sut = encounter1
        let tag = CombatantTag(
            id: UUID(),
            definition: CombatantTagDefinition.all[0],
            note: nil,
            duration: EffectDuration.until(EncounterMoment.turnEnd(EncounterMoment.Turn.target), skipping: 0),
            addedIn: sut.turn,
            sourceCombatantId: nil
        )
        sut.current.combatants[0].tags.append(tag)

        XCTAssertEqual(sut.tagExpiresAt(tag, sut.current.combatants[0]), RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[1].id))
    }

    func testTagExpiryDurationUntilStartOfTargetNextTurn() {
        var sut = encounter1
        let tag = CombatantTag(
            id: UUID(),
            definition: CombatantTagDefinition.all[0],
            note: nil,
            duration: EffectDuration.until(EncounterMoment.turnStart(EncounterMoment.Turn.target), skipping: 0),
            addedIn: sut.turn,
            sourceCombatantId: nil
        )
        sut.current.combatants[0].tags.append(tag)

        XCTAssertEqual(sut.tagExpiresAt(tag, sut.current.combatants[0]), RunningEncounter.Turn(round: 2, combatantId: sut.current.combatants[0].id))
    }

    func testTagExpiryDurationUntilStartOfTarget2ndTurn() {
        var sut = encounter1
        let tag = CombatantTag(
            id: UUID(),
            definition: CombatantTagDefinition.all[0],
            note: nil,
            duration: EffectDuration.until(EncounterMoment.turnStart(EncounterMoment.Turn.target), skipping: 1),
            addedIn: sut.turn,
            sourceCombatantId: nil
        )
        sut.current.combatants[0].tags.append(tag)

        XCTAssertEqual(sut.tagExpiresAt(tag, sut.current.combatants[0]), RunningEncounter.Turn(round: 3, combatantId: sut.current.combatants[0].id))
    }

    func testTagExpiryMinute() {
        var sut = encounter1
        let tag = CombatantTag(
            id: UUID(),
            definition: CombatantTagDefinition.all[0],
            note: nil,
            duration: EffectDuration.timeInterval(DateComponents(minute: 1)),
            addedIn: sut.turn,
            sourceCombatantId: nil
        )
        sut.current.combatants[0].tags.append(tag)

        XCTAssertEqual(sut.tagExpiresAt(tag, sut.current.combatants[0]), RunningEncounter.Turn(round: 11, combatantId: sut.current.combatants[0].id))
    }

    func testTurnIsBeforeTurn() {
        let sut = encounter1

        XCTAssertTrue(sut.isTurn(
            RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id),
            before: RunningEncounter.Turn(round: 2, combatantId: sut.current.combatants[0].id)))

        XCTAssertTrue(sut.isTurn(
            RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id),
            before: RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[1].id)))

        XCTAssertFalse(sut.isTurn(
            RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id),
            before: RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id)))

        XCTAssertFalse(sut.isTurn(
            RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[1].id),
            before: RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id)))

        XCTAssertFalse(sut.isTurn(
            RunningEncounter.Turn(round: 2, combatantId: sut.current.combatants[0].id),
            before: RunningEncounter.Turn(round: 1, combatantId: sut.current.combatants[0].id)))
    }


    var encounter1: RunningEncounter {
        let encounter = Encounter(name: "", combatants: [
            Combatant(
                definition: AdHocCombatantDefinition(id: UUID()),
                initiative: 20
            ),
            Combatant(
                definition: AdHocCombatantDefinition(id: UUID()),
                initiative: 15
            ),
            Combatant(
                definition: AdHocCombatantDefinition(id: UUID()),
                initiative: 10
            )
        ])

        return RunningEncounter(
            id: UUID(),
            base: encounter,
            current: encounter,
            turn: RunningEncounter.Turn(
                round: 1,
                combatantId: encounter.combatants[0].id),
            log: []
        )
    }

}
