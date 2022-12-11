//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import OpenAIClient
import Persistence

public struct MechMuse {
    private var openAIClient: OpenAIClient? = nil

    private let describeAction: (OpenAIClient, CreatureActionDescriptionRequest, ToneOfVoice) async throws -> String

    public init(
        describeAction: @escaping (OpenAIClient, CreatureActionDescriptionRequest, ToneOfVoice) async throws -> String
    ) {
        self.describeAction = describeAction
    }
}

public extension MechMuse {
    func describe(action: CreatureActionDescriptionRequest, toneOfVoice: ToneOfVoice) async throws -> String {
        guard let openAIClient else {
            throw MechMuseError.unconfigured
        }
        return try await describeAction(openAIClient, action, toneOfVoice)
    }
}

public extension MechMuse {
    static func live(db: Database) -> Self {
        MechMuse(
            describeAction: { client, request, toneOfVoice in
                let prompt = request.prompt(toneOfVoice: toneOfVoice)
                print(prompt)
                let response = try await client.perform(request: CompletionRequest(
                    model: .Davinci3,
                    prompt: prompt,
                    maxTokens: 350
                ))
                return response.choices.first?.text
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                ?? ""
            }
        )
    }

    static let noop: Self = MechMuse(describeAction: { _ ,_ , _ in
        return ""
    })
}

public enum MechMuseError: Swift.Error {
    case unconfigured
    case quotaExceeded
}

public protocol EnvironmentWithMechMuse {
    var mechMuse: MechMuse { get }
}
