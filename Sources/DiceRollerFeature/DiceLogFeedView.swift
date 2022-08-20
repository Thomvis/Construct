//
//  DiceLogFeedView.swift
//  Construct
//
//  Created by Thomas Visser on 29/12/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Dice

public struct DiceLogFeedView: View {
    let entries: [DiceLogEntry]

    public init(entries: [DiceLogEntry]) {
        self.entries = entries
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { p in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 12) {
                        Color.clear.frame(height: 80) // for the top safe area & gradient (FIXME)

                        ForEach(entries.suffix(20), id: \.id) { entry in
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.roll.title).font(.footnote).bold()
                                    .multilineTextAlignment(.trailing)

                                VStack(alignment: .trailing, spacing: 8) {
                                    ForEach(entry.results.suffix(20), id: \.id) { result in
                                        VStack(alignment: .trailing, spacing: 2) {
                                            if let singleRoll = result.singleRoll {
                                                singleRollView(singleRoll)
                                            } else if let (first, second) = result.doubleRoll {
                                                HStack(spacing: -5) {
                                                    doubleRollComponentView(first, isFirst: true)
                                                    doubleRollComponentView(second, isFirst: false)
                                                }
                                            }

                                            result.effectiveResult.text
                                                .font(.caption2)
                                                .foregroundColor(Color.secondary)
                                        }
                                        .transition(.move(edge: .leading).combined(with: .opacity).animation(.default.delay(0.1)))
                                    }
                                }
                                .padding(.trailing, 12)
                                .background(alignment: .trailing) {
                                    Color(UIColor.systemGray2)
                                        .frame(maxWidth: 2)
                                        .padding(.trailing, 1)
                                }
                            }
                            .transition(.opacity)
                        }

                        Color.clear.frame(height: 15).id("bottom") // for the bottom gradient (FIXME)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .bottomTrailing)
                }
                .onChange(of: entries.last) { _ in
                    DispatchQueue.main.async {
                        withAnimation(.spring()) {
                            p.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.spring()) {
                            p.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func singleRollView(_ displayRoll: DisplayRoll) -> some View {
        coreRollComponentView(displayRoll)
            .padding(6)
            .frame(minWidth: 33, minHeight: 33)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 2))
                    .foregroundColor(Color(UIColor.systemGray5))
            )
            .opacity(displayRoll.opacity)
    }

    private func doubleRollComponentView(_ displayRoll: DisplayRoll, isFirst: Bool) -> some View {
        coreRollComponentView(displayRoll)
            .padding(EdgeInsets(top: 6, leading: isFirst ? 4 : 8, bottom: 6, trailing: isFirst ? 8 : 4))
            .frame(minWidth: 33, minHeight: 33)
            .background(
                doubleRollBackground(isFirst: isFirst)
            )
            .opacity(displayRoll.opacity)
    }

    private func coreRollComponentView(_ displayRoll: DisplayRoll) -> some View {
        Text("\(displayRoll.expression.total)")
                    .underline(displayRoll.expression.total == displayRoll.expression.unroll.maximum)
                    .italic(displayRoll.expression.total == displayRoll.expression.unroll.minimum)
                    .foregroundColor(displayRoll.foregroundColor)
                    .opacity(displayRoll.opacity)
                    .font(.body)
    }

    private func doubleRollBackground(isFirst: Bool) -> some View {
        Canvas { context, size in
            let lineWidth: CGFloat = 2.0
            let slantedness: CGFloat = 0.2
            let gap: CGFloat = 0
            let cr: CGFloat = 4

            let safeArea = CGRect(x: lineWidth/2, y: lineWidth/2, width: size.width - lineWidth, height: size.height - lineWidth)

            if isFirst {
                let leftPoints: [CGPoint] = [
                    CGPoint(x: safeArea.minX, y: safeArea.minY),
                    CGPoint(x: safeArea.maxX*(1-gap), y: lineWidth/2),
                    CGPoint(x: safeArea.maxX*(1-gap-slantedness), y: safeArea.maxY),
                    CGPoint(x: safeArea.minX, y: safeArea.maxY)
                ]

                var left = Path()
                left.move(to: leftPoints[0].offset(dx: cr))
                left.addLine(to: leftPoints[1])
                left.addLine(to: leftPoints[2])
                left.addLine(to: leftPoints[3].offset(dx: cr))
                left.addQuadCurve(to: leftPoints[3].offset(dy: -cr), control: leftPoints[3])
                left.addLine(to: leftPoints[0].offset(dy: cr))
                left.addQuadCurve(to: leftPoints[0].offset(dx: cr), control: leftPoints[0])
                left.closeSubpath()

                context.stroke(left, with: .color(Color(UIColor.systemGray5)), lineWidth: 2)
            } else {
                let rightPoints: [CGPoint] = [
                    CGPoint(x: safeArea.maxX, y: safeArea.maxY),
                    CGPoint(x: safeArea.minX, y: safeArea.maxY),
                    CGPoint(x: safeArea.minX+safeArea.maxX*slantedness, y: safeArea.minY),
                    CGPoint(x: safeArea.maxX, y: safeArea.minY)
                ]

                var right = Path()
                right.move(to: rightPoints[0].offset(dx: -cr))
                right.addLine(to: rightPoints[1])
                right.addLine(to: rightPoints[2])
                right.addLine(to: rightPoints[3].offset(dx: -cr))
                right.addQuadCurve(to: rightPoints[3].offset(dy: cr), control: rightPoints[3])
                right.addLine(to: rightPoints[0].offset(dy: -cr))
                right.addQuadCurve(to: rightPoints[0].offset(dx: -cr), control: rightPoints[0])
                right.closeSubpath()

                context.stroke(right, with: .color(Color(UIColor.systemGray5)), lineWidth: 2)
            }
        }
    }
}

fileprivate extension DiceLogEntry.Result {

    var singleRoll: DisplayRoll? {
        second == nil ? DisplayRoll(expression: first, emphasis: .none) : nil
    }

    var doubleRoll: (DisplayRoll, DisplayRoll)? {
        guard let second = second else { return nil }

        return (
            DisplayRoll(expression: first, emphasis: .init(for: first, versus: second, type: type)),
            DisplayRoll(expression: second, emphasis: .init(for: second, versus: first, type: type))
        )
    }
}

fileprivate struct DisplayRoll {
    let expression: RolledDiceExpression
    let emphasis: Emphasis

    var foregroundColor: Color? {
        switch emphasis {
        case .none: return nil
        case .demphasize: return nil
        case .lowestWithDisadvantage: return Color(UIColor.systemRed)
        case .highestWithAdvantage: return Color(UIColor.systemGreen)
        }
    }

    var opacity: Double {
        switch emphasis {
        case .demphasize: return 0.33
        case .none, .lowestWithDisadvantage, .highestWithAdvantage:
            return 1.0
        }
    }

    enum Emphasis {
        case none
        case demphasize
        case lowestWithDisadvantage
        case highestWithAdvantage

        init(for roll: RolledDiceExpression, versus other: RolledDiceExpression, type: DiceLogEntry.Result.ResultType) {
            switch type {
            case .normal: self = .none
            case .advantage:
                if roll.total > other.total {
                    self = .highestWithAdvantage
                } else if roll.total < other.total {
                    self = .demphasize
                } else {
                    self = .none
                }
            case .disadvantage:
                if roll.total < other.total {
                    self = .lowestWithDisadvantage
                } else if roll.total > other.total {
                    self = .demphasize
                } else {
                    self = .none
                }
            }
        }
    }
}
