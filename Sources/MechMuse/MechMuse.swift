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
    private var client: CurrentValue<OpenAI?>
    private let describeAction: (OpenAI, CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>
    private let describeCombatants: (OpenAI, GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream<GenerateCombatantTraitsResponse.Traits, Error>
    private let generateStatBlock: (OpenAI, GenerateStatBlockRequest) async throws -> SimpleStatBlock?
    private let verifyAPIKey: (OpenAI) async throws -> Void

    public var isConfigured: Bool {
        (try? client.value) != nil
    }

    public init(
        client: CurrentValue<OpenAI?>,
        describeAction: @escaping (OpenAI, CreatureActionDescriptionRequest) throws -> AsyncThrowingStream<String, Error>,
        describeCombatants: @escaping (OpenAI, GenerateCombatantTraitsRequest) throws -> AsyncThrowingStream< GenerateCombatantTraitsResponse.Traits, Error>,
        generateStatBlock: @escaping (OpenAI, GenerateStatBlockRequest) async throws -> SimpleStatBlock?,
        verifyAPIKey: @escaping (OpenAI) async throws -> Void
    ) {
        self.client = client
        self.describeAction = describeAction
        self.describeCombatants = describeCombatants
        self.generateStatBlock = generateStatBlock
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

    func generate(statBlock request: GenerateStatBlockRequest) async throws -> SimpleStatBlock? {
        guard let openAIClient = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return try await generateStatBlock(openAIClient, request)
    }

    func verifyAPIKey(_ key: String) async throws {
        let client = OpenAI(apiToken: key)
        try await verifyAPIKey(client)
    }
}

public extension MechMuse {
    static func live(db: Database) -> Self {
        live(
            client: db.keyValueStore.observe(Preferences.key)
                .map(\.?.mechMuse.apiKey).removeDuplicates()
                .map { key in
                    key?.nonEmptyString.map {
                        OpenAI(configuration: OpenAI.Configuration(
                            token: $0,
                            timeoutInterval: 180
                        ))
                    }
                }
                .stream
                .currentValue(nil)
        )
    }

    private static let model: Model = .gpt5

    static func live(client: CurrentValue<OpenAI?>) -> Self {
        MechMuse(
            client: client,
            describeAction: { client, request in
                let prompt = request.prompt()

                return AsyncThrowingStream(String.self) { continuation in
                    Task.detached {
                        do {
                            let response = try await client.responses.createResponse(
                                query: CreateModelResponseQuery(
                                    input: .inputItemList(prompt),
                                    model: Self.model,
                                    reasoning: CreateModelResponseQuery.Schemas.Reasoning(effort: .low)
                                )
                            )

                            if let content = response.outputText {
                                continuation.yield(content)
                            }
                            continuation.finish()
                        } catch {
                            if let error = error as? APIError {
                                continuation.finish(throwing: MechMuseError(from: error))
                            } else {
                                continuation.finish(throwing: MechMuseError.unspecified)
                            }
                        }
                    }
                }

                // Stream doesn't seem to work (maybe limitation of my account?)

//                return client.responses.createResponseStreaming(query: CreateModelResponseQuery(
//                    input: .inputItemList(prompt),
//                    model: Self.model,
//                    stream: true
//                ))
//                .compactMap { streamEvent in
//                    if case .inProgress(let event) = streamEvent {
//                        return event.response.outputText
//                    }
//                    return nil
//                }
//                .mapError { error in
//                    if let error = error as? APIError {
//                        return MechMuseError(from: error)
//                    }
//                    return MechMuseError.unspecified
//                }
//                .stream
            },
            describeCombatants: { client, request in
                assert(!request.combatantNames.isEmpty)
                let prompt = request.prompt()

//                typealias TraitsArray = [GenerateCombatantTraitsResponse.Traits]
//                let endToken = "[Construct::END]"
//
//                return chain(
//                    client.chatsStream(query: ChatQuery(
//                        messages: prompt,
//                        model: Self.model,
//                        maxCompletionTokens: 150 * max(request.combatantNames.count, 1),
//                        temperature: 0.9
//                    ))
//                    .compactMap { chatStreamResult in
//                        chatStreamResult.choices[0].delta.content
//                    }
//                    .mapError { error in
//                        if let error = error as? APIError {
//                            return MechMuseError(from: error)
//                        }
//                        return MechMuseError.unspecified
//                    },
//                    [endToken].async
//                )
//                // reduce the tokens into a growing (partial) response
//                .reductions(into: "", { acc, elem in
//                    acc += elem
//                })
//                // parse every (partial) response
//                .map { acc -> TraitsArray in
//                    if acc.hasSuffix(endToken) {
//
//                        do {
//                            let traits = try GenerateCombatantTraitsResponse.parser.parse(String(acc.dropLast(endToken.count)))
//
//                            if traits.isEmpty {
//                                throw MechMuseError.unspecified // is upgraded to .interpretationFailed below
//                            }
//
//                            // we're at the end of the response, add a dummy Traits that is removed in the next operator
//                            return traits + [.init(name: "", physical: "", personality: "", nickname: "")]
//                        } catch {
//                            throw MechMuseError.interpretationFailed(
//                                text: String(acc.dropLast(endToken.count)),
//                                error: String(describing: error)
//                            )
//                        }
//                    } else {
//                        do {
//                            return try GenerateCombatantTraitsResponse.parser.parse(acc)
//                        } catch {
//                            return []
//                        }
//                    }
//                }
//                // remember all seen traits
//                .reductions(into: (TraitsArray(), TraitsArray()), { traits, parsed in
//                    // drop the last because it might be incomplete
//                    let new = parsed.dropLast(1).filter { t in
//                        !traits.0.contains(t)
//                    }
//                    traits = (traits.0 + new, new)
//                })
//                // emit just the new traits
//                .flatMap { (all, new) in
//                    return new.async
//                }.stream

                return AsyncThrowingStream(GenerateCombatantTraitsResponse.Traits.self) { continuation in
                    Task.detached {
                        do {
                            let response = try await client.responses.createResponse(query: CreateModelResponseQuery(
                                input: .inputItemList(prompt),
                                model: Self.model,
                                reasoning: CreateModelResponseQuery.Schemas.Reasoning(effort: .low),
                                text: .jsonSchema(.init(
                                    name: "combatant_traits_response",
                                    schema: .dynamicJsonSchema(GenerateCombatantTraitsResponse.schema.definition()),
                                    description: nil,
                                    strict: true
                                ))
                            ))

                            if let content = response.outputText,
                               let traitsResponseData = content.data(using: .utf8) {

                                let traitsResponse = try JSONDecoder().decode(GenerateCombatantTraitsResponse.self, from: traitsResponseData)
                                for traits in traitsResponse.combatantTraits {
                                    continuation.yield(traits)
                                }
                            } else {
                                continuation.finish(throwing: MechMuseError.unspecified)
                            }

                            continuation.finish()
                        } catch {
                            if let error = error as? APIError {
                                continuation.finish(throwing: MechMuseError(from: error))
                            } else {
                                continuation.finish(throwing: MechMuseError.unspecified)
                            }
                        }
                    }
                }
            },
            generateStatBlock: { client, request in
                let prompt = request.prompt()

                do {
                    let response = try await client.responses.createResponse(query: CreateModelResponseQuery(
                        input: .inputItemList(prompt),
                        model: Self.model,
                        reasoning: CreateModelResponseQuery.Schemas.Reasoning(effort: .low),
                        text: .jsonSchema(.init(
                            name: "simple_stat_block",
                            schema: .dynamicJsonSchema(SimpleStatBlock.schema.definition()),
                            description: nil,
                            strict: false
                        ))
                    ))

                    if let content = response.outputText,
                       let data = content.data(using: .utf8) {
                        let result = try JSONDecoder().decode(SimpleStatBlock.self, from: data)
                        return result
                    }
                    return nil
                } catch {
                    if let error = error as? APIError {
                        throw MechMuseError(from: error)
                    } else {
                        throw MechMuseError.unspecified
                    }
                }
            },
            verifyAPIKey: { client in
                _ = try await client.models()
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
        generateStatBlock: { _, _ in
            return nil
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

extension MechMuse: DependencyKey {
    public static var liveValue: MechMuse {
        @Dependency(\.database) var database
        return .live(db: database)
    }
}

public extension DependencyValues {
    var mechMuse: MechMuse {
        get { self[MechMuse.self] }
        set { self[MechMuse.self] = newValue }
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
