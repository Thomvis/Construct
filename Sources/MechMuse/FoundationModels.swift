import FoundationModels

public extension MechMuse {
    @available(iOS 27.0, *)
    static func foundationModels() -> Self {
        return MechMuse(
            describeAction: { request in
                return .never
            },
            describeCombatants: { request in
                let session = LanguageModelSession(profile: MechMuseProfile(
                    instructions: Instructions {
                        GenerateCombatantTraitsRequest.systemInstructions
                    }
                ))
                
                return AsyncThrowingStream(GenerateCombatantTraitsResponse.Traits.self) { continuation in
                    Task.detached {
                        do {
                            let traits = try await session.respond(
                                to: Prompt {
                                    request.userQuery
                                },
                                generating: GenerateCombatantTraitsResponse.self
                            )
                            for traits in traits.content.combatantTraits {
                                continuation.yield(traits)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: MechMuseError.unspecified)
                        }
                    }
                }
            },
            generateStatBlock: { request in
                return nil
            },
            isConfigured: {
                true
            },
            verifyConfiguration: {
                
            }
        )
    }
}

@available(iOS 27.0, *)
fileprivate struct MechMuseProfile: LanguageModelSession.DynamicProfile {
    var instructions: Instructions
    var model = PrivateCloudComputeLanguageModel()
    
    var body: some LanguageModelSession.DynamicProfile {
        Profile {
            instructions
        }
        .model(model)
//        .model(SystemLanguageModel.default)
    }
    
    // When PrivateCloudComputeLanguageModel is configured, session.respond fails with these logs:
    //
    //    Passing along Operation not permitted: Operation not permitted in response to CreateSessionRequest
    //    establishment of session failed with Operation not permitted: Operation not permitted
    //    Received ModelManagerError that couldn't be converted to a TokenGenerationError: Operation not permitted: Operation not permitted
    //    Printing description of error:
    //    Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSMultipleUnderlyingErrorsKey=(
    //        "Error Domain=FoundationModels.LanguageModelError Code=-1 \"(null)\" UserInfo={NSMultipleUnderlyingErrorsKey=(\n    \"Error Domain=ModelManagerServices.ModelManagerError Code=1046 \\\"(null)\\\" UserInfo={NSMultipleUnderlyingErrorsKey=(\\n)}\"\n)}"
    //    ), NSLocalizedDescription=The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)}
}
