import Evaluations
import Testing
import MechMuse
import CustomDump
import FoundationModels

@available(iOS 27.0, *)
struct DescribeCombatantsEvaluation: Evaluation {
    let mechMuse: MechMuse
    
    func subject(from sample: DescribeCombatantsSample) async throws -> ModelSubject<[GenerateCombatantTraitsResponse.Traits]> {
        let result = try await Array(mechMuse.describeCombatants(sample.input))
        return ModelSubject(value: result)
    }
    
    var dataset = ArrayLoader(samples: [
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: [])
        ),
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: ["Goblin 1", "Goblin 2", "Bugbear"])
        ),
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: ["Phase Spider 1", "Phase Spider 2"])
        ),
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: ["Red Wizard 1", "Red Wizard 2", "Red Wizard 3"])
        ),
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: ["Swarm of Bats 1"])
        ),
        DescribeCombatantsSample(
            input: GenerateCombatantTraitsRequest(combatantNames: ["Kobold 1", "Kobold 2", "Kobold 3", "Kobold 4", "Kobold 5", "Kobold 6", "Kobold 7", "Kobold 8", "Kobold 9", "Kobold 10"])
        ),
    ])
    
    let hasAllCombatants = Metric("Has All Combatants")
    
    var evaluators: Evaluators {
        Evaluator { sample, subject in
            if Set(sample.input.combatantNames) == Set(subject.value.map(\.name)) {
                hasAllCombatants.passing()
            } else {
                hasAllCombatants.failing()
            }
        }
        
//        ModelJudgeEvaluator(
//            judge: SystemLanguageModel.default,
//            dimensions: [],
//            prompt: ModelJudgePrompt(
//                instructions: """
//                    You are evaluating combatant traits generated for a D&D DM companion app.
//                    The traits can give a bit of flair to otherwise "default" monsters, that the
//                    DM can use to create more lively descriptions of combat for their players.
//                    """,
//                evaluationTarget: { value in
//                    ""
//                },
//                reference: { input, _ in
//                    [:]
//                }
//            )
//        )
    }
    
    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: hasAllCombatants)
    }
}

struct DescribeCombatantsSample: SampleProtocol {
    var input: GenerateCombatantTraitsRequest
    var expected: [GenerateCombatantTraitsResponse.Traits]?
}

@Suite
struct DescribeCombatantsEvaluationTests {
    @available(iOS 27.0, *)
    static let evaluation = DescribeCombatantsEvaluation(mechMuse: MechMuse.foundationModels())
    
    static let evaluationInfo: [String: String] = [
        "ModelName": "PrivateCloudComputeModel",
        "AppVersion": "3.1.1"
    ]
    
    @available(iOS 27.0, *)
    @Test(.evaluates(evaluation, info: evaluationInfo))
    func evaluateDescribeCombatants() async throws {
        let result = EvaluationContext.current.result

        let hasAllCombatantsMetric = DescribeCombatantsEvaluationTests.evaluation.hasAllCombatants
        #expect(result.aggregateValue(.mean(of: hasAllCombatantsMetric)) >= 0.95)
    }
}

extension GenerateCombatantTraitsRequest: CustomStringConvertible {
    public var description: String {
        String(customDumping: self)
    }
}
