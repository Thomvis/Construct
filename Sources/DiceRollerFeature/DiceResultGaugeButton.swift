//
//  DiceResultGaugeButton.swift
//  Construct
//
//  Created by Codex on 12/06/2026.
//

import Dice
import SwiftUI

struct DiceResultGaugeButton: View {
    let total: Int
    let expression: DiceExpression
    let isIntermediary: Bool
    let action: () -> Void

    @Environment(\.controlSize) private var controlSize
    @State private var animatesExtreme = false
    @State private var animatedQuality = 0.0

    var body: some View {
        let metrics = self.metrics

        Button(action: action) {
            ZStack {
                GaugeArc(progress: 1)
                    .stroke(
                        Color(UIColor.secondarySystemFill),
                        style: StrokeStyle(lineWidth: metrics.lineWidth, lineCap: .round)
                    )

                if !isIntermediary {
                    GaugeArc(progress: animatedQuality)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: metrics.lineWidth, lineCap: .round)
                        )
                    
                    if let extreme {
                        ExtremeRollIcon(extreme: extreme, color: color, size: metrics.iconSize)
                    } else {
                        VStack(spacing: metrics.percentSpacing) {
                            Text(animatedQuality * 100, format: .number.precision(.fractionLength(0)))
                                .font(metrics.percentFont)
                                .contentTransition(.numericText())
                            
                            Text("%")
                                .font(metrics.percentSignFont)
                        }
                        .foregroundStyle(.secondary)
                        .offset(y: metrics.percentOffsetY)
                    }
                }
            }
            .frame(width: metrics.width, height: metrics.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Roll statistics")
        .accessibilityValue("\(total)")
        .onAppear {
            viewAppeared()
        }
        .onChange(of: total) {
            totalChanged()
        }
    }

    private var quality: Double {
        expression.probabilityDistribution
            .cumulativeProbability(atMost: total)
            .clamped(to: 0...1)
    }

    private var metrics: Metrics {
        switch controlSize {
        case .mini:
            Metrics(
                width: 32,
                height: 26,
                lineWidth: 4,
                iconSize: 13,
                percentFont: .caption2,
                percentSignFont: .system(size: 8, weight: .thin, design: .monospaced),
                percentSpacing: -3,
                percentOffsetY: 1
            )
        case .small:
            Metrics(
                width: 38,
                height: 31,
                lineWidth: 4.5,
                iconSize: 15,
                percentFont: .caption,
                percentSignFont: .system(size: 9, weight: .thin, design: .monospaced),
                percentSpacing: -4,
                percentOffsetY: 1
            )
        case .large:
            Metrics(
                width: 52,
                height: 42,
                lineWidth: 6,
                iconSize: 21,
                percentFont: .headline,
                percentSignFont: .system(size: 12, weight: .thin, design: .monospaced),
                percentSpacing: -5,
                percentOffsetY: 2
            )
        default:
            Metrics(
                width: 44,
                height: 36,
                lineWidth: 5,
                iconSize: 18,
                percentFont: .subheadline,
                percentSignFont: .system(size: 10, weight: .thin, design: .monospaced),
                percentSpacing: -4,
                percentOffsetY: 2
            )
        }
    }

    private var color: Color {
        Color(hue: 0.02 + 0.30 * quality, saturation: 0.88, brightness: 0.95)
    }

    private var extreme: Extreme? {
        if total == expression.minimum, expression.minimum != expression.maximum {
            return .lowest
        }
        if total == expression.maximum, expression.minimum != expression.maximum {
            return .highest
        }
        return nil
    }

    fileprivate enum Extreme {
        case lowest
        case highest
    }

    private struct Metrics {
        let width: CGFloat
        let height: CGFloat
        let lineWidth: CGFloat
        let iconSize: CGFloat
        let percentFont: Font
        let percentSignFont: Font
        let percentSpacing: CGFloat
        let percentOffsetY: CGFloat
    }

    private func viewAppeared() {
        animatedQuality = 0
        totalChanged()
    }

    private func totalChanged() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
            animatedQuality = quality
        }

        animatesExtreme = false
        if extreme != nil {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.48).delay(0.08)) {
                animatesExtreme = true
            }
        }
    }
}

private struct GaugeArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let range = 250.0
        let startAngle = Angle(degrees: 90 + (360 - range)/2)
        let endAngle = startAngle + Angle(degrees: range) * progress.clamped(to: 0...1)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private struct ExtremeRollIcon: View {
    let extreme: DiceResultGaugeButton.Extreme
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolEffect(.bounce.wholeSymbol, options: .repeat(.periodic(delay: 1.0)))
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }

    private var systemName: String {
        switch extreme {
        case .lowest:
            return "xmark"
        case .highest:
            return "star.fill"
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#if DEBUG
struct DiceResultGaugeButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                DiceResultGaugeButton(total: 1, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 10, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 20, expression: 1.d(20), isIntermediary: false) {}
            }
            .controlSize(.mini)

            HStack(spacing: 16) {
                DiceResultGaugeButton(total: 1, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 10, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 20, expression: 1.d(20), isIntermediary: false) {}
            }
            .controlSize(.small)

            HStack(spacing: 16) {
                DiceResultGaugeButton(total: 1, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 10, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 20, expression: 1.d(20), isIntermediary: false) {}
            }

            HStack(spacing: 16) {
                DiceResultGaugeButton(total: 1, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 10, expression: 1.d(20), isIntermediary: false) {}
                DiceResultGaugeButton(total: 20, expression: 1.d(20), isIntermediary: false) {}
            }
            .controlSize(.large)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
#endif
