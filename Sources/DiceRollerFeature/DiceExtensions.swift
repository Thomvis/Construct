//
//  File.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation
import Dice
import GameModels
import Helpers
import ComposableArchitecture

public extension RollDescription {
    static func abilityCheck(_ modifier: Int, ability: Ability, skill: Skill? = nil, creatureName: String? = nil) -> Self {
        @Dependency(\.modifierFormatter) var modifierFormatter

        var title = AttributedString("\(modifierFormatter.string(from: modifier))")

        title += AttributedString(" \(ability.localizedDisplayName)")

        if let skill = skill {
            title += AttributedString(" (\(skill.localizedDisplayName))")
        }

        title += AttributedString(" Check")

        if let creatureName = creatureName {
            title += AttributedString(" - \(creatureName)")
        }

        return RollDescription(
            expression: 1.d(20)+modifier,
            title: title
        )
    }
}
