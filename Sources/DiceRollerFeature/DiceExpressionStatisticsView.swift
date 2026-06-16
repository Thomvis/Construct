//
//  DiceExpressionStatisticsView.swift
//  Construct
//
//  Created by Codex on 12/06/2026.
//

import Charts
import Dice
import SwiftUI

public struct DiceExpressionStatisticsView: View {
    let expression: DiceExpression
    let highlightedValue: Int?
    @State private var displayMode: DiceExpressionDistribution.DisplayMode

    public init(
        expression: DiceExpression,
        highlightedValue: Int? = nil,
        displayMode: DiceExpressionDistribution.DisplayMode = .normal
    ) {
        self.expression = expression
        self.highlightedValue = highlightedValue
        self._displayMode = State(initialValue: displayMode)
    }

    public var body: some View {
        let distribution = expression.probabilityDistribution
        let outcomes = distribution.outcomes(displayMode: displayMode)

        VStack(spacing: 14) {
            Picker("Display mode", selection: $displayMode.animation(.default)) {
                ForEach(DiceExpressionDistribution.DisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            DiceProbabilityGraph(outcomes: outcomes, highlightedValue: highlightedValue)
                .frame(height: 168)

            DiceProbabilityTable(
                outcomes: outcomes,
                highlightedValue: highlightedValue,
                displayMode: displayMode
            )
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
    }
}

private struct DiceProbabilityGraph: View {
    let outcomes: [DiceExpressionDistribution.Outcome]
    let highlightedValue: Int?

    var body: some View {
        VStack(spacing: 6) {
            Chart {
                ForEach(outcomes) { outcome in
                    AreaMark(
                        x: .value("Value", outcome.value),
                        y: .value("Probability", outcome.probability)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Color.accentColor.opacity(0.18))

                    LineMark(
                        x: .value("Value", outcome.value),
                        y: .value("Probability", outcome.probability)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.accentColor)

                    PointMark(
                        x: .value("Value", outcome.value),
                        y: .value("Probability", outcome.probability)
                    )
                    .symbolSize(26)
                    .foregroundStyle(Color.accentColor)
                }

                if let highlightedOutcome {
                    RuleMark(x: .value("Highlighted value", highlightedOutcome.value))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .foregroundStyle(Color.yellow.opacity(0.75))

                    PointMark(
                        x: .value("Highlighted value", highlightedOutcome.value),
                        y: .value("Highlighted probability", highlightedOutcome.probability)
                    )
                    .symbolSize(130)
                    .foregroundStyle(Color.yellow)
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: 0...yScaleUpperBound)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color(UIColor.separator))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color(UIColor.secondarySystemBackground))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                if let first = outcomes.first {
                    Text("\(first.value)")
                }
                Spacer()
                Text(Self.percentFormatter.string(from: NSNumber(value: maxProbability)) ?? "")
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = outcomes.last {
                    Text("\(last.value)")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var maxProbability: Double {
        outcomes.map(\.probability).max() ?? 0
    }

    private var xDomain: ClosedRange<Int> {
        (outcomes.first?.value ?? 0)...(outcomes.last?.value ?? 1)
    }

    private var highlightedOutcome: DiceExpressionDistribution.Outcome? {
        guard let highlightedValue else { return nil }
        return outcomes.first { $0.value == highlightedValue }
    }

    private var yScaleUpperBound: Double {
        max(maxProbability * 1.08, 0.01)
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

private struct DiceProbabilityTable: View {
    let outcomes: [DiceExpressionDistribution.Outcome]
    let highlightedValue: Int?
    let displayMode: DiceExpressionDistribution.DisplayMode

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(outcomes) { outcome in
                        HStack(spacing: 10) {
                            Text("\(outcome.value)")
                                .font(.body.monospacedDigit())
                                .frame(width: 42, alignment: .trailing)

                            DiceProbabilityBar(
                                outcome: outcome,
                                maxProbability: maxProbability,
                                isHighlighted: outcome.value == highlightedValue
                            )

                            Text(Self.percentFormatter.string(from: NSNumber(value: outcome.probability)) ?? "")
                                .font(.body.monospacedDigit())
                                .frame(width: 70, alignment: .trailing)
                        }
                        .frame(height: 28)
                        .padding(.horizontal, 8)
                        .background {
                            if outcome.value == highlightedValue {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.yellow.opacity(0.18))
                            }
                        }
                        .overlay {
                            if outcome.value == highlightedValue {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.yellow.opacity(0.70), lineWidth: 1)
                            }
                        }
                        .id(outcome.value)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                scrollToHighlightedValue(with: proxy)
            }
            .onChange(of: highlightedValue) {
                scrollToHighlightedValue(with: proxy)
            }
            .onChange(of: displayMode) {
                scrollToHighlightedValue(with: proxy)
            }
        }
    }

    private var maxProbability: Double {
        outcomes.map(\.probability).max() ?? 0
    }

    private func scrollToHighlightedValue(with proxy: ScrollViewProxy) {
        guard let highlightedValue else { return }
        proxy.scrollTo(highlightedValue, anchor: .center)
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

private struct DiceProbabilityBar: View {
    let outcome: DiceExpressionDistribution.Outcome
    let maxProbability: Double
    let isHighlighted: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(UIColor.secondarySystemBackground))

                Capsule()
                    .fill(isHighlighted ? Color.yellow.opacity(0.85) : Color.accentColor.opacity(0.78))
                    .frame(width: proxy.size.width * barScale)
            }
        }
        .frame(height: 10)
    }

    private var barScale: CGFloat {
        guard maxProbability > 0 else { return 0 }
        return CGFloat(outcome.probability / maxProbability)
    }
}

private extension DiceExpressionDistribution.DisplayMode {
    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .atLeast:
            return "At least"
        case .atMost:
            return "At most"
        }
    }
}

#if DEBUG
struct DiceExpressionStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiceExpressionStatisticsView(expression: 2.d(6) + 3)
    }
}
#endif
