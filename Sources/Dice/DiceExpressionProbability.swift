//
//  DiceExpressionProbability.swift
//  Construct
//
//  Created by Codex on 12/06/2026.
//

import Foundation

public struct DiceExpressionDistribution: Hashable {
    public struct Outcome: Hashable, Identifiable {
        public var id: Int { value }

        public let value: Int
        public let probability: Double

        public init(value: Int, probability: Double) {
            self.value = value
            self.probability = probability
        }
    }

    public enum DisplayMode: String, CaseIterable, Hashable, Identifiable {
        case normal
        case atLeast
        case atMost

        public var id: Self { self }
    }

    public let probabilitiesByValue: [Int: Double]

    public init(probabilitiesByValue: [Int: Double]) {
        self.probabilitiesByValue = probabilitiesByValue.filter { $0.value > 0 }
    }

    public var outcomes: [Outcome] {
        probabilitiesByValue
            .map { Outcome(value: $0.key, probability: $0.value) }
            .sorted { $0.value < $1.value }
    }

    public func probability(of value: Int) -> Double {
        probabilitiesByValue[value] ?? 0
    }

    public func cumulativeProbability(atMost value: Int) -> Double {
        outcomes(displayMode: .atMost)
            .last { $0.value <= value }?
            .probability ?? 0
    }

    public func outcomes(displayMode: DisplayMode) -> [Outcome] {
        let sortedOutcomes = outcomes

        switch displayMode {
        case .normal:
            return sortedOutcomes

        case .atLeast:
            var cumulativeProbability = 0.0
            return sortedOutcomes
                .reversed()
                .map { outcome in
                    cumulativeProbability += outcome.probability
                    return Outcome(value: outcome.value, probability: cumulativeProbability)
                }
                .reversed()

        case .atMost:
            var cumulativeProbability = 0.0
            return sortedOutcomes.map { outcome in
                cumulativeProbability += outcome.probability
                return Outcome(value: outcome.value, probability: cumulativeProbability)
            }
        }
    }
}

public extension DiceExpression {
    var probabilityDistribution: DiceExpressionDistribution {
        switch self {
        case .dice(let count, let die):
            guard die.sides > 0 else {
                return DiceExpressionDistribution(probabilitiesByValue: [:])
            }

            let sign = count < 0 ? -1 : 1
            let dieDistribution = (1...die.sides).reduce(into: [Int: Double]()) { result, value in
                result[value * sign] = 1.0 / Double(die.sides)
            }

            return DiceExpressionDistribution(
                probabilitiesByValue: (0..<abs(count)).reduce([0: 1.0]) { distribution, _ in
                    distribution.combined(with: dieDistribution, combine: +)
                }
            )

        case .compound(let lhs, let op, let rhs):
            return DiceExpressionDistribution(
                probabilitiesByValue: lhs.probabilityDistribution.probabilitiesByValue.combined(
                    with: rhs.probabilityDistribution.probabilitiesByValue,
                    combine: op.f
                )
            )

        case .number(let value):
            return DiceExpressionDistribution(probabilitiesByValue: [value: 1.0])
        }
    }
}

private extension Dictionary where Key == Int, Value == Double {
    func combined(with other: Self, combine: (Int, Int) -> Int) -> Self {
        reduce(into: Self()) { result, lhs in
            other.forEach { rhs in
                result[combine(lhs.key, rhs.key), default: 0] += lhs.value * rhs.value
            }
        }
    }
}
