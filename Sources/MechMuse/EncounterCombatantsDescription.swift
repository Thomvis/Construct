//
//  EncounterCombatantsDescription.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import Parsing

public struct EncounterCombatantsDescriptionRequest {
    let combatantNames: [String] // names with discriminator

    public init(combatantNames: [String]) {
        self.combatantNames = combatantNames
    }
}

public struct EncounterCombatantsDescription: Equatable {
    public let descriptions: [String: Description]

    public init(descriptions: [String : Description]) {
        self.descriptions = descriptions
    }

    public struct Description: Equatable {
        public let appearance: String
        public let behavior: String
        public let nickname: String

        public init(appearance: String, behavior: String, nickname: String) {
            self.appearance = appearance
            self.behavior = behavior
            self.nickname = nickname
        }
    }
}

extension EncounterCombatantsDescriptionRequest: PromptConvertible {
    public func prompt(toneOfVoice: ToneOfVoice) -> String {
        let namesList = combatantNames.joined(separator: ", ")

        // Prompt notes:
        // - Spelling out D&D because it yields slightly longer responses
        return """
        A Dungeons & Dragons encounter has the following monsters: \(namesList). Come up with unique details for each monster's appearance and behavior (in keywords) and a fitting nickname, without interfering with its stats.

        Format your answer as correct YAML dictionary, using fields appearance, behavior, nickname.
        """
    }
}

extension EncounterCombatantsDescription {
    static let parser = Parse {
        Whitespace()

        Many(into: [String: EncounterCombatantsDescription.Description]()) { acc, elem in
            acc[elem.0] = elem.1
        } element: {
            Prefix { $0 != ":" }.map(.string)
            ":"
            Whitespace()
            singleParser
        } separator: {
            Whitespace()
        }.map {
            EncounterCombatantsDescription(descriptions: $0)
        }
    }

    private static let singleParser = Parse(EncounterCombatantsDescription.Description.init(appearance:behavior:nickname:)) {
        "Appearance:"
        Whitespace()
        trimmedString
        Whitespace()

        "Behavior:"
        Whitespace()
        trimmedString
        Whitespace()

        "Nickname:"
        Whitespace()
        trimmedString
    }

    private static let trimmedString = Prefix { !$0.isNewline }.map {
        $0.trimmingCharacters(in: CharacterSet(["\"", "'"]))
    }
}
