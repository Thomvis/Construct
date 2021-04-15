//
//  StatBlockCombatantResources.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

extension StatBlock {
    func extractResources() -> [CombatantResource] {
        var result: [CombatantResource] = []
        // Spellcasting
        if let spellcastingFeat = features.first(where: { $0.name.localizedCaseInsensitiveContains("spellcasting") }) {
            let s = spellcastingFeat.description

            let expression = try? NSRegularExpression(pattern: "(?<level>\\d)[\\w ]* \\((?<slots>[\\d]+) slot", options: [])
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            let matches = expression?.matches(in: s, options: [], range: range)

            let ordinalFormatter = NumberFormatter()
            ordinalFormatter.numberStyle = .ordinal

            for match in matches ?? [] {
                let levelRange = match.range(withName: "level")
                let slotsRange = match.range(withName: "slots")
                guard levelRange.location != NSNotFound,
                    slotsRange.location != NSNotFound,
                    let lr = Range(levelRange, in: s),
                    let level = Int(s[lr]),
                    let levelOrdinal = ordinalFormatter.string(for: level),
                    let sr = Range(slotsRange, in: s),
                    let slots = Int(s[sr]) else {
                        continue
                }
                result.append(CombatantResource(
                    id: UUID().tagged(),
                    title: "\(levelOrdinal) level spell slots",
                    slots: Array(repeating: false, count: slots)
                ))
            }
        }

        // Rechargable actions
        for action in actions {
            if action.name.localizedCaseInsensitiveContains("recharg") {
                result.append(CombatantResource(id: UUID().tagged(), title: action.name, slots: [false]))
            }
        }

        // X per day use features
        let nPerDay = try? NSRegularExpression(pattern: "(\\d+)\\/Day", options: [])
        for f in features {
            let range = NSRange(f.name.startIndex..<f.name.endIndex, in: f.name)
            if let match = nPerDay?.firstMatch(in: f.name, options: [], range: range) {
                let countRange = match.range(at: 1)
                if countRange.location != NSNotFound, let r = Range(countRange, in: f.name), let c = Int(f.name[r]) {
                    result.append(CombatantResource(id: UUID().tagged(), title: f.name, slots: Array(repeating: false, count: c)))
                }
            }
        }

        return result
    }
}
