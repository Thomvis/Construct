//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import OpenAIClient
import Persistence
import Helpers
import GameModels
import Parsing
import AsyncAlgorithms

/// Errors must be of type MechMuseError
public struct MechMuse {
    private var client: CurrentValue<OpenAIClient?>
    private let describeAction: (OpenAIClient, CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>
    private let describeCombatants: (OpenAIClient, GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream<GenerateCombatantTraitsResponse.Traits, Error>
    private let verifyAPIKey: (OpenAIClient) async throws -> Void

    public init(
        client: CurrentValue<OpenAIClient?>,
        describeAction: @escaping (OpenAIClient, CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>,
        describeCombatants: @escaping (OpenAIClient, GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error>,
        verifyAPIKey: @escaping (OpenAIClient) async throws -> Void
    ) {
        self.client = client
        self.describeAction = describeAction
        self.describeCombatants = describeCombatants
        self.verifyAPIKey = verifyAPIKey
    }
}

public extension MechMuse {
    /// The returned AsyncThrowingStream emits tokens as they come in from the API. To get the full response,
    /// these tokens need to be concatenated.
    func describe(action: CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error> {
        guard let openAIClient = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return try describeAction(openAIClient, action)
    }

    /// The returned AsyncThrowingStream emits traits per combatant as they are parsed from the API response
    func describe(combatants request: GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error> {
        guard let openAIClient = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return try describeCombatants(openAIClient, request)
    }

    func verifyAPIKey(_ key: String) async throws {
        try await verifyAPIKey(OpenAIClient.live(apiKey: key))
    }
}

public extension MechMuse {
    static func live(db: Database) -> Self {
        live(
            client: db.keyValueStore.observe(Preferences.key)
                .map(\.?.mechMuse.apiKey).removeDuplicates()
                .map { key in key.map { OpenAIClient.live(apiKey: $0) } }
                .stream
                .currentValue(nil)
        )
    }

    static func live(client: CurrentValue<OpenAIClient?>) -> Self {
        MechMuse(
            client: client,
            describeAction: { client, request in
                let prompt = request.prompt()

                do {
                    return try client.stream(request: ChatCompletionRequest(
                        messages: prompt,
                        maxTokens: 350,
                        temperature: 0.9
                    ))
                } catch let error as OpenAIError {
                    throw MechMuseError(from: error)
                } catch {
                    throw MechMuseError.unspecified
                }
            },
            describeCombatants: { client, request in
                do {
                    let response = try await client.perform(request: request.chatRequest())
                    guard
                        let content = response.choices.first?.message.content,
                        let data = content.data(using: .utf8)
                    else {
                        throw MechMuseError.unspecified
                    }

                    let wrapper = try JSONDecoder().decode(GenerateCombatantTraitsResponse.self, from: data)
                    return wrapper.combatants.async.stream
                } catch let error as OpenAIError {
                    throw MechMuseError(from: error)
                } catch {
                    throw MechMuseError.unspecified
                }
            },
            verifyAPIKey: { client in
                _ = try await client.performModelsRequest()
            }
        )
    }

    static let unconfigured: Self = MechMuse(
        client: .none,
        describeAction: { _ ,_ in
            [].async.stream
        },
        describeCombatants: { _, _ in
            [].async.stream
        },
        verifyAPIKey: { _ in

        }
    )
}

public enum MechMuseError: Error, Equatable {
    case unconfigured
    case unspecified
    case interpretationFailed(text: String?, error: String)
    case insufficientQuota
    case invalidAPIKey

    public init(from error: OpenAIError) {
        switch error {
        case .remote(let remoteError):
            switch remoteError.code {
            case .invalidAPIKey: self = .invalidAPIKey
            case .insufficientQuota: self = .insufficientQuota
            case .contextLengthExceeded: self = .unspecified // map to unspecified because the user can't help it anyway
            case .none: self = .unspecified
            }
        case .decodingFailed:
            self = .unspecified
        case .unexpected:
            self = .unspecified
        }
    }

    public var attributedDescription: AttributedString {
        switch self {
        case .unconfigured: return try! AttributedString(markdown: "This feature is powered by Mechanical Muse: an Artificial Intelligence made to inspire your DM'ing. Set up Mechanical Muse in the settings screen.")
        case .unspecified: return AttributedString("The operation failed due to an unknown error.")
        case .interpretationFailed(_, let s): return AttributedString(s)
        case .insufficientQuota: return try! AttributedString(markdown: "You have exceeded your OpenAI usage limits. Please update your OpenAI [account settings](https://beta.openai.com/account/billing/limits).")
        case .invalidAPIKey: return AttributedString("Invalid OpenAI API Key. Please check the Mechanical Muse configuration in the settings screen.")
        }
    }
}

public protocol EnvironmentWithMechMuse {
    var mechMuse: MechMuse { get }
}

extension MechMuseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .interpretationFailed(_, let reason): return "MechMuseError.interpretationFailed(\(reason))"
        default: return String(describing: self)
        }
    }
}
