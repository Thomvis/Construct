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

/// Errors must be of type MechMuseError
public struct MechMuse {
    private var client: CurrentValue<OpenAIClient?>
    private let describeAction: (OpenAIClient, CreatureActionDescriptionRequest, ToneOfVoice) async throws -> String
    private let describeCombatants: (OpenAIClient, GenerateCombatantTraitsRequest) async throws -> GeneratedCombatantTraits
    private let verifyAPIKey: (OpenAIClient) async throws -> Void

    public init(
        clientProvider: AsyncThrowingStream<OpenAIClient?, any Error>,
        describeAction: @escaping (OpenAIClient, CreatureActionDescriptionRequest, ToneOfVoice) async throws -> String,
        describeCombatants: @escaping (OpenAIClient, GenerateCombatantTraitsRequest) async throws -> GeneratedCombatantTraits,
        verifyAPIKey: @escaping (OpenAIClient) async throws -> Void
    ) {
        self.client = CurrentValue(initialValue: nil, updates: clientProvider)
        self.describeAction = describeAction
        self.describeCombatants = describeCombatants
        self.verifyAPIKey = verifyAPIKey
    }
}

public extension MechMuse {
    func describe(action: CreatureActionDescriptionRequest, toneOfVoice: ToneOfVoice) async throws -> String {
        guard let openAIClient = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return try await describeAction(openAIClient, action, toneOfVoice)
    }

    func describe(combatants request: GenerateCombatantTraitsRequest) async throws -> GeneratedCombatantTraits {
        guard let openAIClient = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return try await describeCombatants(openAIClient, request)
    }

    func verifyAPIKey(_ key: String) async throws {
        try await verifyAPIKey(OpenAIClient.live(apiKey: key))
    }
}

public extension MechMuse {
    static func live(db: Database) -> Self {
        live(
            clientProvider: db.keyValueStore.observe(Preferences.key)
            .map(\.?.mechMuse.apiKey).removeDuplicates()
            .map { key in key.map { OpenAIClient.live(apiKey: $0) } }
            .stream
        )
    }

    static func live(clientProvider: AsyncThrowingStream<OpenAIClient?, any Error>) -> Self {
        MechMuse(
            clientProvider: clientProvider,
            describeAction: { client, request, toneOfVoice in
                let prompt = request.prompt(toneOfVoice: toneOfVoice)

                do {
                    let response = try await client.perform(request: CompletionRequest(
                        model: .Davinci3,
                        prompt: prompt,
                        maxTokens: 350,
                        temperature: 0.9
                    ))
                    return response.choices.first?.text
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    ?? ""
                } catch let error as OpenAIError {
                    throw MechMuseError(from: error)
                } catch {
                    throw MechMuseError.unspecified
                }
            },
            describeCombatants: { client, request in
                let prompt = request.prompt(toneOfVoice: .gritty)
                do {
                    let response = try await client.perform(request: CompletionRequest(
                        model: .Davinci3,
                        prompt: prompt,
                        maxTokens: 150 * request.combatantNames.count,
                        temperature: 0.9
                    ))
                    return try (response.choices.first?.text).map {
                        try GeneratedCombatantTraits.parser.parse($0)
                    } ?? GeneratedCombatantTraits(traits: [:])
                } catch let error as OpenAIError {
                    throw MechMuseError(from: error)
                } catch let error as CustomDebugStringConvertible {
                    throw MechMuseError.unexpected(error.debugDescription)
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
        clientProvider: AsyncThrowingStream { nil },
        describeAction: { _ ,_ , _ in
            ""
        },
        describeCombatants: { _, _ in
            .init(traits: [:])
        },
        verifyAPIKey: { _ in

        }
    )
}

public enum MechMuseError: Error, Equatable {
    case unconfigured
    case unspecified
    case unexpected(String)
    case insufficientQuota
    case invalidAPIKey

    public init(from error: OpenAIError) {
        switch error {
        case .remote(let remoteError):
            switch remoteError.code {
            case .invalidAPIKey: self = .invalidAPIKey
            case .insufficientQuota: self = .insufficientQuota
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
        case .unexpected(let s): return AttributedString(s)
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
        case .unexpected(let reason): return "MechMuseError.unexpected(\(reason))"
        default: return String(describing: self)
        }
    }
}
