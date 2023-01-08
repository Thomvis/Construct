//
//  MechMuseTest.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import XCTest
import MechMuse
import GameModels
import OpenAIClient
import CustomDump

final class MechMuseTest: XCTestCase {

    @MainActor
    func testEncounterCombatantsTraitsSuccess() async throws {
        let response = CompletionResponse(id: "", object: "", created: 0, model: "", choices: [
            .init(text: """


            Thug 1:
            Physical: Scruffy-looking, scarred face, wears leather armor
            Personality: Boastful, crude, rarely thinks ahead
            Nickname: "Sneaky Slasher"

            Thug 2:
            Physical: Unkempt, unshaven, wears chainmail
            Personality: Cautious, follows orders, prefers to attack from a distance
            Nickname: Angry Toothpick

            Bandit Captain 1:
            Physical: Neatly dressed, scarred face, wears studded leather armor
            Personality: Charismatic, calculating, commands respect
            Nickname: "Charming Charly"
            """, finishReason: "")
        ])
        let openAIClient = OpenAIClient.simpleMock(completionResponse: response)
        let sut = MechMuse.live(clientProvider: AsyncThrowingStream([openAIClient].async))

        let result = try await sut.describe(combatants: .init(
            combatantNames: ["Thug 1", "Thug 2", "Bandit Captain 1"]
        ))

        XCTAssertNoDifference(result, GeneratedCombatantTraits(traits: [
            "Thug 1": .init(
                physical: "Scruffy-looking, scarred face, wears leather armor",
                personality: "Boastful, crude, rarely thinks ahead",
                nickname: "Sneaky Slasher"
            ),
            "Thug 2": .init(
                physical: "Unkempt, unshaven, wears chainmail",
                personality: "Cautious, follows orders, prefers to attack from a distance",
                nickname: "Angry Toothpick"
            ),
            "Bandit Captain 1": .init(
                physical: "Neatly dressed, scarred face, wears studded leather armor",
                personality: "Charismatic, calculating, commands respect",
                nickname: "Charming Charly"
            )
        ]))
    }

    @MainActor
    func testEncounterCombatantsTraitsParseError() async throws {
        let response = CompletionResponse(id: "", object: "", created: 0, model: "", choices: [
            .init(text: """
            Thug 1 =
            Physicala: Scruffy-looking, scarred face, wears leather armor
            """, finishReason: "")
        ])
        let openAIClient = OpenAIClient.simpleMock(completionResponse: response)
        let sut = MechMuse.live(clientProvider: AsyncThrowingStream([openAIClient].async))

        do {
            _ = try await sut.describe(combatants: .init(
                combatantNames: ["Thug 1", "Thug 2", "Bandit Captain 1"]
            ))
            XCTFail("Expected an error")
        } catch MechMuseError.interpretationFailed(_, let msg) {
            XCTAssertEqual(msg, """
            error: unexpected input
             --> input:1:1
            1 | Thug 1 =
              | ^ expected end of input
            """)
        }
    }

}

extension OpenAIClient {
    static func simpleMock(
        completionResponse: CompletionResponse,
        modelsResponse: ModelsResponse = ModelsResponse()
    ) -> Self {
        return OpenAIClient(
            performCompletionRequest: { _ in completionResponse },
            performModelsRequest: { modelsResponse }
        )
    }
}
