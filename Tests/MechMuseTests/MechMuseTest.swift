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
        let response = """
            ```yaml
            - name: Goblin 1
              physical: Covered in scars from past battles, one eye is missing and replaced by an eyepatch.
              personality: Highly aggressive and enjoys taunting their enemies before attacking.
              nickname: "Scarface"

            - name: Goblin 2
              physical: Unusually tall and lanky for a goblin, with long fingers and an unnerving grin.
              personality: Extremely sneaky and enjoys setting traps for unsuspecting adventurers.
              nickname: The Trickster
            ```
            """

        let openAIClient = OpenAIClient.simpleMock(
            performCompletionResponse: nil,
            streamCompletionResponse: nil,
            streamChatResponse: [response].async.stream
        )
        let sut = MechMuse.live(client: .constant(openAIClient))

        let result = try sut.describe(combatants: .init(
            combatantNames: ["Goblin 1", "Goblin 2"]
        ))

        let traits = try await result.reduce(into: []) { array, t in
            array.append(t)
        }

        XCTAssertNoDifference(traits, [
            .init(
                name: "Goblin 1",
                physical: "Covered in scars from past battles, one eye is missing and replaced by an eyepatch",
                personality: "Highly aggressive and enjoys taunting their enemies before attacking",
                nickname: "Scarface"
            ),
            .init(
                name: "Goblin 2",
                physical: "Unusually tall and lanky for a goblin, with long fingers and an unnerving grin",
                personality: "Extremely sneaky and enjoys setting traps for unsuspecting adventurers",
                nickname: "The Trickster"
            )
        ])
    }

    @MainActor
    func testEncounterCombatantsTraitsParseError() async throws {
        let response = """
            Thug 1 =
            Physicala: Scruffy-looking, scarred face, wears leather armor
            """
        let openAIClient = OpenAIClient.simpleMock(
            performCompletionResponse: nil,
            streamCompletionResponse: nil,
            streamChatResponse: [response].async.stream
        )
        let sut = MechMuse.live(client: .constant(openAIClient))

        do {
            let result = try sut.describe(combatants: .init(
                combatantNames: ["Thug 1", "Thug 2", "Bandit Captain 1"]
            ))

            for try await _ in result { }
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
        performCompletionResponse: CompletionResponse?,
        streamCompletionResponse: AsyncThrowingStream<String, Error>?,
        streamChatResponse: AsyncThrowingStream<String, Error>?,
        modelsResponse: ModelsResponse = ModelsResponse()
    ) -> Self {
        return OpenAIClient(
            performCompletionRequest: { _ in performCompletionResponse! },
            streamCompletionRequest: { _ in streamCompletionResponse! },
            streamChatRequest: { _ in streamChatResponse! },
            performModelsRequest: { modelsResponse }
        )
    }
}
