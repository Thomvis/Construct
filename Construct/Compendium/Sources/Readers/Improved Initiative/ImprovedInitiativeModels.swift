//
//  ImprovedInitiativeModels.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

enum ImprovedInitiative {
    struct Creature: Codable {
        let Id: String
        let Name: String
        let `Type`: String
        let HP: Annotated<Int>
        let AC: Annotated<Int>
        let InitiativeModifier: Int
        let InitiativeAdvantage: Bool
        let Speed: [String]
        let Abilities: Abilities

        let DamageVulnerabilities: [String]
        let DamageResistances: [String]
        let DamageImmunities: [String]
        let ConditionImmunities: [String]
        let Saves: [NamedModifier]
        let Skills: [NamedModifier]
        let Senses: [String]
        let Languages: [String]
        let Challenge: String
        let Traits: [TraitOrAction]
        let Actions: [TraitOrAction]
        let Reactions: [TraitOrAction]
        let LegendaryActions: [TraitOrAction]
        let Description: String

        struct Annotated<Value: Codable>: Codable {
            let Value: Value
            let Notes: String
        }

        struct Abilities: Codable {
            let Str, Dex, Con, Int, Wis, Cha: Int
        }

        struct NamedModifier: Codable {
            let Name: String
            let Modifier: Int?
        }

        struct TraitOrAction: Codable {
            let Name: String
            let Content: String
            let Usage: String
        }
    }
}
