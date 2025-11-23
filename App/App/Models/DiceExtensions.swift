//
//  DiceExtensions.swift
//  Construct
//
//  Created by Thomas Visser on 19/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import DiceRollerFeature
import GameModels

extension RollDescription {
    static func abilityCheck(_ modifier: Int, ability: Ability, skill: Skill? = nil, combatant: Combatant? = nil) -> Self {
        .abilityCheck(modifier, ability: ability, skill: skill, creatureName: combatant?.discriminatedName)
    }
}
