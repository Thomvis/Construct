//
//  EncounterDifficultyView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct EncounterDifficultyView: View {

    let difficulty: EncounterDifficulty

    let listFormatter = ListFormatter()

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                //Text(challengeText)
                ZStack {
                    Bar(color: Color(UIColor.systemGray5), percentage: 1)
                    if difficulty.category != nil {
                        Bar(color: barColor, percentage: max(0, min(1, difficulty.percentageOfDeadly))).animation(.spring())
                    }

                    GeometryReader { proxy in
                        ForEach(EncounterDifficulty.Category.allCases.dropLast()) { c in
                            Group {
                                // draw difficulty thresholds
                                Circle()
                                    .fill(Color(UIColor.systemBackground).opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .offset(x: proxy.size.width*self.difficulty.percentageOfDeadly(c)-4, y: 0)
                            }
                        }
                    }.frame(height: 8)

                    percentageOverDeadlyText.map {
                        Text($0).bold()
                            .foregroundColor(Color.white)
                            .padding(.trailing, 8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            (Text(challengeText).bold() + Text(" for \(partySummary)").foregroundColor(Color(UIColor.secondaryLabel))).font(.footnote)
        }.padding(.top, 3)
    }

    var challengeText: String {
        guard let category = difficulty.category else {
            return "No challenge"
        }

        switch category {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .deadly: return "Deadly"
        }
    }

    var partySummary: String {
        var items: [String] = []
        var anonymousLevelsCovered: [Int] = []
        for entry in difficulty.party {
            if let name = entry.name {
                items.append(name)
            } else if !anonymousLevelsCovered.contains(entry.level) {
                let count = difficulty.party.filter { $0.level == entry.level && $0.name == nil }.count
                if count == 1 {
                    items.append("\(count) level \(entry.level) character")
                } else {
                    items.append("\(count) level \(entry.level) characters")
                }
                anonymousLevelsCovered.append(entry.level)
            }
        }

        return listFormatter.string(from: items) ?? "unknown"
    }

    var percentageOverDeadlyText: String? {
        guard difficulty.percentageOfDeadly > 1.1 else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .percent

        guard let str = formatter.string(for: difficulty.percentageOfDeadly - 1) else { return nil }

        return "+\(str)"
    }

    var barColor: Color {
        guard let category = difficulty.category else {
            return Color(UIColor.systemGray)
        }

        switch category {
        case .easy: return Color(UIColor.systemGreen)
        case .medium: return Color(UIColor.systemYellow)
        case .hard: return Color(UIColor.systemOrange)
        case .deadly: return Color(UIColor.systemRed)
        }
    }
}

fileprivate struct Bar: View {
    let color: Color
    let percentage: CGFloat

    var body: some View {
        GeometryReader { proxy in
            BarShape(percentage: self.percentage).stroke(self.color, style: StrokeStyle(
                lineWidth: proxy.size.height,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 0,
                dash: [],
                dashPhase: 0
            ))
        }
        .frame(height: 20)
    }

    struct BarShape: Shape {
        var percentage: CGFloat

        var animatableData: CGFloat {
            get { percentage }
            set { percentage = newValue }
        }

        func path(in rect: CGRect) -> Path {
            Path { path in
                let padding = min(rect.size.height, rect.size.width)*0.5
                let scaleWidth = rect.size.width - 2*padding
                path.move(to: CGPoint(x: padding, y: rect.size.height*0.5))
                path.addLine(to: CGPoint(x: padding+scaleWidth*self.percentage, y: rect.size.height*0.5))
            }
        }
    }
}

extension EncounterDifficultyView {
    init?(encounter: Encounter) {
        guard !encounter.partyWithEntriesForDifficulty.1.isEmpty && !encounter.combatants.isEmpty else { return nil }
        self.init(difficulty: EncounterDifficulty(
            party: encounter.partyWithEntriesForDifficulty.1,
            monsters: encounter.combatants.compactMap { $0.definition.stats?.challengeRating }
        ))
    }
}
