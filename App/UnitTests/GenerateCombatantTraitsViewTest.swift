//
//  GenerateCombatantTraitsViewTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 08/01/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import ComposableArchitecture
import GameModels
import Helpers
import MechMuse
import OpenAI

class GenerateCombatantTraitsViewTest: XCTestCase {

    @MainActor
    func testErrorReporting() async {
        let env = TestEnvironment()
        let store = TestStore(
            initialState: GenerateCombatantTraitsViewState(
                encounter: Encounter(
                    name: "Test",
                    combatants: [
                        Combatant(adHoc: .init(
                            id: UUID().tagged(),
                            stats: apply(StatBlock.default) {
                                $0.name = "Goblin"
                            }
                        ))
                    ]
                )
            ),
            reducer: GenerateCombatantTraitsViewState.reducer,
            environment: env
        )

        let error = MechMuseError.interpretationFailed(text: "A", error: "B")
        env.describeCombatantsResult = AsyncThrowingStream { throw error }

        await store.send(.onGenerateTap) {
            $0.isLoading = true
        }
        await store.receive(.onTraitGenerationDidFail(error)) {
            $0.isLoading = false
            $0.error = error
        }
        XCTAssertEqual(env.trackedErrors.count, 1)
        XCTAssert((env.trackedErrors.last?.error as? MechMuseError) == error)
        XCTAssertEqual(env.trackedErrors.last?.attachments, [
            "request": """
            GenerateCombatantTraitsRequest(
              combatantNames: [
                [0]: "Goblin"
              ]
            )
            """
        ])
    }

    class TestEnvironment: GenerateCombatantTraitsViewEnvironment {
        var mechMuse: MechMuse { _mechMuse }
        var crashReporter: CrashReporter { _crashReporter }

        var _mechMuse: MechMuse!
        var _crashReporter: CrashReporter!

        var describeCombatantsCallCount: Int = 0
        var describeCombatantsResult: AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error> = [].async.stream
        var trackedErrors: [CrashReporter.ErrorReport] = []

        init() {
            _mechMuse = MechMuse(
                client: .constant(OpenAI(apiToken: "")),
                describeAction: { _, _ in fatalError() },
                describeCombatants: { client, requests in
                    self.describeCombatantsCallCount += 1
                    return self.describeCombatantsResult
                },
                generateStatBlock: { _, _ in fatalError() },
                verifyAPIKey: { _ in fatalError() }
            )

            _crashReporter = CrashReporter(
                registerUserPermission: { _ in fatalError() },
                trackError: { error in
                    self.trackedErrors.append(error)
                }
            )
        }
    }
}


