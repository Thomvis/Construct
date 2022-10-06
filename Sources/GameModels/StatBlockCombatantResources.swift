//
//  StatBlockCombatantResources.swift
//  Construct
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged
import Helpers

private let legendaryActionCountParser = zip(string("take "), int(), string(" legendary actions")).skippingAnyBefore()

extension StatBlock {
    public func extractResources() -> [CombatantResource] {
        var result: [CombatantResource] = []

        // Features
        for f in features {
            guard let parsedFeature = f.result?.value else { continue }

            // Rechargable features
            if let limitedUse = parsedFeature.limitedUse?.value {
                result.append(CombatantResource(title: f.name, slotCount: limitedUse.amount))
            }

            // Spellcasting
            if let spellcasting = parsedFeature.spellcasting {
                let ordinalFormatter = NumberFormatter()
                ordinalFormatter.numberStyle = .ordinal

                // slots
                if let slotsByLevel = spellcasting.slotsByLevel {
                    for level in slotsByLevel.keys.sorted() {
                        guard let slotCount = slotsByLevel[level], level > 0, let levelOrdinal = ordinalFormatter.string(for: level) else { continue }
                        result.append(CombatantResource(title: "\(levelOrdinal) level spell slots", slotCount: slotCount))
                    }
                }

                // innate
                if let limitedUseSpells = spellcasting.limitedUseSpells {
                    let listFormatter = ListFormatter()
                    for group in limitedUseSpells {
                        guard let limitedUse = group.limitedUse, let title = listFormatter.string(from: group.spells.map { $0.value.text }) else { continue }
                        result.append(CombatantResource(title: "\(title) (\(limitedUse.displayString))", slotCount: limitedUse.amount))
                    }
                }
            }
        }

        // Actions
        for a in actions {
            guard let parsedAction = a.result?.value else { continue }

            // Rechargable actions
            if let limitedUse = parsedAction.limitedUse?.value {
                result.append(CombatantResource(title: a.name, slotCount: limitedUse.amount))
            }
        }

        // Legendary actions
        if let legendaryDescription = legendary?.description,
           let count = legendaryActionCountParser.run(legendaryDescription)?.1 {
            result.append(CombatantResource(id: UUID().tagged(), title: "Legendary Actions", slots: Array(repeating: false, count: count)))
        }

        return result
    }
}
