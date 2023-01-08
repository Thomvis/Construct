//
//  EncounterCombatantsDescription.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import Parsing

public struct GenerateCombatantTraitsRequest {
    public let combatantNames: [String] // names with discriminator

    public init(combatantNames: [String]) {
        self.combatantNames = combatantNames
    }
}

public struct GeneratedCombatantTraits: Equatable {
    public var traits: [String: Traits]

    public init(traits: [String : Traits]) {
        self.traits = traits
    }

    public struct Traits: Equatable {
        public let physical: String
        public let personality: String
        public let nickname: String

        public init(physical: String, personality: String, nickname: String) {
            self.physical = physical
            self.personality = personality
            self.nickname = nickname
        }
    }
}

extension GenerateCombatantTraitsRequest: PromptConvertible {
    public func prompt(toneOfVoice: ToneOfVoice) -> String {
        let namesList = combatantNames.map { "\($0)" }.joined(separator: ", ")

        // Prompt notes:
        // - Spelling out D&D because it yields slightly longer responses
        // - Without quotes around each combatant name, the discriminator could be omitted from the response
        // - Added "Limit each value to a single sentence" to subdue the tendency to give a bulleted list when only
        //   a single combatant was in the request.
        return """
        A Dungeons & Dragons encounter has the following monsters: \(namesList). Come up with \(toneOfVoice) physical and personality traits and a fitting unique nickname, without interfering with its stats. Limit each value to a single sentence.

        Format your answer as a correct YAML dictionary with an entry for each monster. Each entry has fields physical, personality, nickname.
        """
    }
}

extension GeneratedCombatantTraits {
    static let parser = Parse {
        Skip {
            Prefix<Substring> { !$0.isLetter }
        }

        Many(into: [String: GeneratedCombatantTraits.Traits]()) { acc, elem in
            acc[elem.0] = elem.1
        } element: {
            Prefix { $0 != ":" }.map(.string)
            ":"
            Whitespace()
            singleParser
        } separator: {
            Whitespace()
        }.map {
            GeneratedCombatantTraits(traits: $0)
        }
    }

    private static let singleParser = Parse(GeneratedCombatantTraits.Traits.init(physical:personality:nickname:)) {
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
        $0.trimmingCharacters(in: CharacterSet(["\"", "'", "."]))
    }
}
