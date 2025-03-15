//
//  GameModelsVisitorTest.swift
//
//
//  Created by Thomas Visser on 16/12/2023.
//


import Foundation
import GameModels
import XCTest
import SnapshotTesting
import InlineSnapshotTesting
import TestSupport
import Helpers
import CustomDump

final class GameModelsVisitorTest: XCTestCase {
    
    func testVisitRunningEncounter() {
        let uuidGenerator = UUID.fakeGenerator(offset: 5000)

        let base = Encounter(
            id: uuidGenerator(),
            name: "Crazy Encounter",
            combatants: [
                .init(
                    id: uuidGenerator().tagged(),
                    adHoc: .init(
                        id: .init(rawValue: uuidGenerator()),
                        stats: .init(name: "AdHoc Combatant A")
                    )
                ),
                .init(
                    id: uuidGenerator().tagged(),
                    adHoc: .init(
                        id: .init(rawValue: uuidGenerator()),
                        stats: .init(name: "AdHoc Combatant B")
                    )
                ),
                .init(
                    id: uuidGenerator().tagged(),
                    monster: Monster(
                        realm: .init(CompendiumRealm.core.id),
                        stats: .init(name: "Compendium Combatant A"),
                        challengeRating: .oneQuarter
                    )
                )
            ]
        )
        let current = apply(base) { e in
            var rng = SystemRandomNumberGenerator()
            e.rollInitiative(settings: .default, rng: &rng)
            e.combatants.append(Combatant(
                id: uuidGenerator().tagged(),
                adHoc: .init(
                    id: .init(rawValue: uuidGenerator()),
                    stats: .init(name: "Adoc Combatant C")
                )
            ))
        }

        let original = RunningEncounter(
            id: uuidGenerator().tagged(),
            base: base,
            current: current
        )

        let sut = TestVisitor()
        let visited = apply(original, { _ = sut.visit(runningEncounter: &$0) })

        let str = diff(original, visited) ?? ""
        assertSnapshot(of: str, as: .lines)
    }

    func testVisitEntry() {
        let uuidGenerator = UUID.fakeGenerator(offset: 5000)

        let original = CompendiumEntry(
            Character(
                id: uuidGenerator().tagged(),
                realm: .init(CompendiumRealm.core.id),
                stats: StatBlock(name: "Sir Tappalot")
            ),
            origin: .created(nil),
            document: .init(
                id: .init(rawValue: "doc"),
                displayName: "Doc"
            )
        )

        let sut = TestVisitor()
        let visited = apply(original, { _ = sut.visit(entry: &$0) })

        let str = diff(original, visited) ?? ""
        assertSnapshot(of: str, as: .lines)
    }

    final class TestVisitor: AbstractGameModelsVisitor {
        let uuidGenerator = UUID.fakeGenerator()

        @VisitorBuilder
        override func visit(encounter: inout Encounter) -> Bool {
            super.visit(encounter: &encounter)
            visitValue(&encounter, keyPath: \.name, value: "visited")
        }

        @VisitorBuilder
        override func visit(runningEncounter: inout RunningEncounter) -> Bool {
            super.visit(runningEncounter: &runningEncounter)
            visitValue(&runningEncounter, keyPath: \.turn, value: .init(round: 42, combatantId: .init(rawValue: uuidGenerator())))
        }

        @VisitorBuilder
        override func visit(entry: inout CompendiumEntry) -> Bool {
            super.visit(entry: &entry)
            visitValue(&entry, keyPath: \.origin, value: .created(.init(
                itemTitle: "visited",
                itemKey: .init(
                    type: .monster,
                    realm: .init(CompendiumRealm.core.id),
                    identifier: "visited"
                )
            )))
        }

        @VisitorBuilder
        override func visit(combatant: inout Combatant) -> Bool {
            super.visit(combatant: &combatant)
            visitValue(&combatant, keyPath: \.hp, value: .init(fullHealth: 42))
        }

        @VisitorBuilder
        override func visit(statBlock: inout StatBlock) -> Bool {
            super.visit(statBlock: &statBlock)
            visitValue(&statBlock, keyPath: \.name, value: "visited")
        }

        @VisitorBuilder
        override func visit(itemReference: inout CompendiumItemReference) -> Bool {
            super.visit(itemReference: &itemReference)
            visitValue(&itemReference, keyPath: \.itemTitle, value: "visited")
        }
    }
}
