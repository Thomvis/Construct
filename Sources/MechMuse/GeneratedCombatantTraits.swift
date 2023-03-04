//
//  EncounterCombatantsDescription.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import Parsing
import OpenAIClient

public struct GenerateCombatantTraitsRequest {
    public let combatantNames: [String] // names with discriminator

    public init(combatantNames: [String]) {
        self.combatantNames = combatantNames
    }
}

extension GenerateCombatantTraitsRequest: PromptConvertible {
    public func prompt() -> [ChatMessage] {
        let namesList = combatantNames.map { "\"\($0)\"" }.joined(separator: ", ")

        // Prompt notes:
        // - Spelling out D&D because it yields slightly longer responses
        // - Without quotes around each combatant name, the discriminator could be omitted from the response
        // - Added "Limit each value to a single sentence" to subdue the tendency to give a bulleted list when only
        //   a single combatant was in the request.
        return [
            .init(role: .system, content: "You are helping a Dungeons & Dragons DM create awesome encounters."),
            .init(role: .user, content: """
                The encounter has \(combatantNames.count) monster(s): \(namesList). Come up with gritty physical and personality traits that don't interfere with its stats and unique nickname that fits its traits. One trait of each type for each monster, limit each trait to a single sentence.

                Format your answer as a correct YAML sequence of maps, with an entry for each monster. Each entry has fields name, physical, personality, nickname.
                """
            )
        ]
    }
}

public enum GenerateCombatantTraitsResponse {
    static let parser = Parse {
        Whitespace()

        OneOf {
            Parse {
                "```yaml"
                Whitespace()
                yamlParser
                Whitespace()

                Skip {
                    Optionally { "```" }
                }
            }

            yamlParser
        }

        Whitespace()
    }

    static let yamlParser = Many(into: [Traits]()) { acc, elem in
        acc.append(elem)
    } element: {
        singleParser
    } separator: {
        Whitespace()
    }

    private static let singleParser = Parse(Traits.init(name:physical:personality:nickname:)) {
        "- name: "
        trimmedString
        Whitespace()

        StartsWith("Physical:", by: { $0.lowercased() == $1.lowercased() })
        Whitespace()
        trimmedString
        Whitespace()

        StartsWith("Personality:", by: { $0.lowercased() == $1.lowercased() })
        Whitespace()
        trimmedString
        Whitespace()

        StartsWith("Nickname:", by: { $0.lowercased() == $1.lowercased() })
        Whitespace()
        trimmedString
    }

    private static let trimmedString = Prefix { !$0.isNewline }.map {
        $0.trimmingCharacters(in: CharacterSet(["\"", "'", ".", " "]))
    }

    public struct Traits: Equatable, Hashable {
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
