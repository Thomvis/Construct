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
    func testEncounterCombatantsDescription() async throws {
        let response = CompletionResponse(id: "", object: "", created: 0, model: "", choices: [
            .init(text: """


            Thug 1:
            Appearance: Scruffy-looking, scarred face, wears leather armor
            Behavior: Boastful, crude, rarely thinks ahead
            Nickname: "Sneaky Slasher"

            Thug 2:
            Appearance: Unkempt, unshaven, wears chainmail
            Behavior: Cautious, follows orders, prefers to attack from a distance
            Nickname: Angry Toothpick

            Bandit Captain 1:
            Appearance: Neatly dressed, scarred face, wears studded leather armor
            Behavior: Charismatic, calculating, commands respect
            Nickname: "Charming Charly"
            """, finishReason: "")
        ])
        let openAIClient = OpenAIClient.simpleMock(completionResponse: response)
        let sut = MechMuse.live(clientProvider: AsyncThrowingStream([openAIClient].async))

        let description = try await sut.describe(combatants: .init(
            combatantNames: ["Thug 1", "Thug 2", "Bandit Captain 1"]
        ))

        XCTAssertNoDifference(description, EncounterCombatantsDescription(descriptions: [
            "Thug 1": .init(
                appearance: "Scruffy-looking, scarred face, wears leather armor",
                behavior: "Boastful, crude, rarely thinks ahead",
                nickname: "Sneaky Slasher"
            ),
            "Thug 2": .init(
                appearance: "Unkempt, unshaven, wears chainmail",
                behavior: "Cautious, follows orders, prefers to attack from a distance",
                nickname: "Angry Toothpick"
            ),
            "Bandit Captain 1": .init(
                appearance: "Neatly dressed, scarred face, wears studded leather armor",
                behavior: "Charismatic, calculating, commands respect",
                nickname: "Charming Charly"
            )
        ]))
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
