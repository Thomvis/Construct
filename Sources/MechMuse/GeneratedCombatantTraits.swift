//
//  EncounterCombatantsDescription.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import OpenAIClient

public struct GenerateCombatantTraitsRequest {
    public let combatantNames: [String] // names with discriminator

    public init(combatantNames: [String]) {
        self.combatantNames = combatantNames
    }
}

extension GenerateCombatantTraitsRequest {
    func messages() -> [ChatMessage] {
        let namesList = combatantNames.joined(separator: ", ")
        return [
            .init(role: .system, content: "You are helping a Dungeons & Dragons DM create awesome encounters."),
            .init(role: .user, content: "Describe gritty physical and personality traits and a unique nickname for each of the following combatants: \(namesList). Respond in JSON with an object that has a `combatants` array of objects each containing `name`, `physical`, `personality`, and `nickname`.")
        ]
    }

    func prompt() -> [ChatMessage] { messages() }

    func chatRequest() -> ChatCompletionRequest {
        ChatCompletionRequest(
            messages: messages(),
            responseFormat: .jsonObject,
            maxTokens: 150 * max(combatantNames.count, 1),
            temperature: 0.9
        )
    }
}

public struct GenerateCombatantTraitsResponse: Codable {
    public var combatants: [Traits]
}

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
