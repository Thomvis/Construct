//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import OpenAI
import Persistence
import Helpers
import GameModels
import Parsing
import AsyncAlgorithms
import ComposableArchitecture

/// Errors must be of type MechMuseError
public struct MechMuse {
    public let describeAction: (CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>
    public let describeCombatants: (GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream<GenerateCombatantTraitsResponse.Traits, Error>
    public let generateStatBlock: (GenerateStatBlockRequest) async throws -> SimpleStatBlock?
    public let verifyConfiguration: () async throws -> Void

    public var isConfigured: () -> Bool

    public init(
        describeAction: @escaping (CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>,
        describeCombatants: @escaping (GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error>,
        generateStatBlock: @escaping (GenerateStatBlockRequest) async throws -> SimpleStatBlock?,
        isConfigured: @escaping () -> Bool,
        verifyConfiguration: @escaping () async throws -> Void
    ) {
        self.describeAction = describeAction
        self.describeCombatants = describeCombatants
        self.generateStatBlock = generateStatBlock
        self.isConfigured = isConfigured
        self.verifyConfiguration = verifyConfiguration
    }
    
    public static let unconfigured: Self = MechMuse(
        describeAction: { _ in
            [].async.stream
        },
        describeCombatants: { _ in
            [].async.stream
        },
        generateStatBlock: { _ in
            return nil
        },
        isConfigured: {
            return false
        },
        verifyConfiguration: {

        }
    )
}

//public extension MechMuse {
//    /// The returned AsyncThrowingStream emits tokens as they come in from the API. To get the full response,
//    /// these tokens need to be concatenated.
//    func describe(action: CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error> {
//        guard let openAIClient = try? client.value else {
//            throw MechMuseError.unconfigured
//        }
//        return try describeAction(openAIClient, action)
//    }
//
//    /// The returned AsyncThrowingStream emits traits per combatant as they are parsed from the API response
//    func describe(combatants request: GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error> {
//        guard let openAIClient = try? client.value else {
//            throw MechMuseError.unconfigured
//        }
//        return try describeCombatants(openAIClient, request)
//    }
//
//    func generate(statBlock request: GenerateStatBlockRequest) async throws -> SimpleStatBlock? {
//        guard let openAIClient = try? client.value else {
//            throw MechMuseError.unconfigured
//        }
//        return try await generateStatBlock(openAIClient, request)
//    }
//
//    func verifyAPIKey(_ key: String) async throws {
//        let client = OpenAI(apiToken: key)
//        try await verifyAPIKey(client)
//    }
//}

public enum MechMuseError: Error, Equatable {
    case unconfigured
    case unspecified
    case interpretationFailed(text: String?, error: String)
    case insufficientQuota
    case invalidAPIKey

    public init(from error: APIError) {
        switch error.code {
        case "invalid_api_key": self = .invalidAPIKey
        case "insufficient_quota": self = .insufficientQuota
        case "context_length_exceeded": self = .unspecified // map to unspecified because the user can't help it anyway
        default: self = .unspecified
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

struct MechMuseDependencyKey: DependencyKey {
    public static var liveValue: MechMuse {
        @Dependency(\.database) var database
        return .live(db: database)
    }
}

public extension DependencyValues {
    var mechMuse: MechMuse {
        get { self[MechMuseDependencyKey.self] }
        set { self[MechMuseDependencyKey.self] = newValue }
    }
}

extension ResponseObject {
    var outputText: String? {
        var result = ""
        for item in output {
            if case .outputMessage(let msg) = item {
                for c in msg.content {
                    if case .OutputTextContent(let txt) = c {
                        result += txt.text
                    }
                }
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyString
    }
}
