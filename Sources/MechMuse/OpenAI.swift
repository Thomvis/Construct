import Persistence
import OpenAI
import Helpers
import GameModels
import Foundation

public extension MechMuse {
    static func live(db: Database) -> Self {
        live(
            client: db.keyValueStore.observe(Preferences.key)
                .map { prefs in
                    if prefs?.mechMuse.enabled == true {
                        return prefs?.mechMuse.apiKey
                    }
                    return nil
                }
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
            describeAction: { request in
                let client = try requireClient(client: client)
                
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
            describeCombatants: { request in
                let client = try requireClient(client: client)
                
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
            generateStatBlock: { request in
                let client = try requireClient(client: client)
                
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
            isConfigured: { (try? client.value) != nil },
            verifyConfiguration: {
                let client = try requireClient(client: client)
                _ = try await client.models()
            }
        )
    }
    
    static func requireClient(client: CurrentValue<OpenAI?>) throws -> OpenAI {
        guard let client = try? client.value else {
            throw MechMuseError.unconfigured
        }
        return client
    }
}
