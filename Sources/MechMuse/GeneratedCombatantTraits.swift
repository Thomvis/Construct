//
//  EncounterCombatantsDescription.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import Parsing
import OpenAI
import JSONSchemaBuilder

public struct GenerateCombatantTraitsRequest {
    public let combatantNames: [String] // names with discriminator

    public init(combatantNames: [String]) {
        self.combatantNames = combatantNames
    }
}

extension GenerateCombatantTraitsRequest: PromptConvertible {
    public func prompt() -> [InputItem] {
        let namesList = combatantNames.map { "\"\($0)\"" }.joined(separator: ", ")

        // Prompt notes:
        // - Spelling out D&D because it yields slightly longer responses
        // - Without quotes around each combatant name, the discriminator could be omitted from the response
        // - Added "Limit each value to a single sentence" to subdue the tendency to give a bulleted list when only
        //   a single combatant was in the request.
        return [
            .inputMessage(.init(role: .system, content: .textInput("You are helping a Dungeons & Dragons DM create awesome encounters."))),
            .inputMessage(.init(role: .user, content: .textInput("""
                The encounter has \(combatantNames.count) monster(s): \(namesList). Come up with gritty physical and personality traits that don't interfere with its stats and unique nickname that fits its traits. One trait of each type for each monster, limit each trait to a single sentence.
                """
            )))
        ]
    }
}

@Schemable
public struct GenerateCombatantTraitsResponse: Codable {
    public let combatantTraits: [Traits]

    @Schemable
    public struct Traits: Codable, Equatable, Hashable {
        public let name: String
        public let physical: String
        public let personality: String
        public let nickname: String

        public init(name: String, physical: String, personality: String, nickname: String) {
            self.name = name
            self.physical = physical
            self.personality = personality
            self.nickname = nickname
        }
    }
}
