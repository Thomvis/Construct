//
//  DiceLogFeedView.swift
//  Construct
//
//  Created by Thomas Visser on 29/12/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct DiceLogFeedView: View {
    let entries: [DiceLogEntry]

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { p in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 12) {
                        Color.clear.frame(height: 80) // for the top safe area & gradient (FIXME)

                        ForEach(entries.suffix(20), id: \.id) { entry in
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.rollDescription).font(.footnote).bold()

                                VStack(alignment: .trailing, spacing: 8) {
                                    ForEach(entry.results.suffix(20), id: \.id) { result in
                                        VStack(alignment: .trailing, spacing: 2) {
                                            HStack {
                                                ForEach(result.displayRolls, id: \.isFirst) { roll in
                                                    displayRollView(roll)
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
            }
        }
    }

    private func displayRollView(_ displayRoll: DisplayRoll) -> some View {
        return Text("\(displayRoll.expression.total)")
            .foregroundColor(displayRoll.foregroundColor)
            .opacity(displayRoll.opacity)
            .font(.body)
            .padding(6)
            .frame(minWidth: 33, minHeight: 33)
//            .background(Color(UIColor.systemGray5).cornerRadius(5))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 2))
                    .foregroundColor(Color(UIColor.systemGray5))
            )
            .opacity(displayRoll.opacity)
    }
}

extension DiceLogEntry {
    var rollDescription: AttributedString {
        switch roll {
        case .custom(let expression):
            return AttributedString(expression.description)
        }
    }
}

fileprivate extension DiceLogEntry.Result {
    var displayRolls: [DisplayRoll] {
        guard let second = second else {
            return [DisplayRoll(isFirst: true, expression: first, emphasis: .none)]
        }

        return [
            DisplayRoll(isFirst: true, expression: first, emphasis: .init(for: first, versus: second, type: type)),
            DisplayRoll(isFirst: false, expression: second, emphasis: .init(for: second, versus: first, type: type))
        ]
    }
}

fileprivate struct DisplayRoll {
    let isFirst: Bool
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
