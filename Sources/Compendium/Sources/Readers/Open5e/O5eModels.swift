//
//  O5eModels.swift
//  Construct
//
//  Created by Thomas Visser on 26/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

public enum O5e {
    // This file was generated from JSON Schema using quicktype, do not modify it directly.
    // To parse the JSON, add this file to your project and do:
    //
    //   let monsters = try? newJSONDecoder().decode(Monsters.self, from: jsonData)

    // MARK: - Monster
    public struct Monster: Decodable {
        let name: String
        let size: String
        let type: String
        let subtype: String
        let alignment: String
        let armorClass, hitPoints: Int
        let hitDice: String
        let speed: Either<String, SpeedJSON>
        let strength, dexterity, constitution, intelligence: Int
        let wisdom, charisma: Int
        let constitutionSave, intelligenceSave, wisdomSave, history: Int?
        let perception: Int?
        let damageVulnerabilities: String
        let damageResistances, damageImmunities, conditionImmunities, senses: String
        let languages, challengeRating: String
        let specialAbilities, actions: Either<[Action], String>?
        let legendaryDesc: String?
        let legendaryActions: Either<[Action], String>?
        let speedJSON: SpeedJSON?
        let armorDesc: String?
        let medicine, religion, dexteritySave, charismaSave: Int?
        let stealth: Int?
        let group: String?
        let persuasion, insight, deception, arcana: Int?
        let athletics, acrobatics, strengthSave: Int?
        let reactions: Either<[Action], String>?
        let survival, investigation, nature, intimidation: Int?
        let performance, animalHandling, sleightOfHand: Int?

        enum CodingKeys: String, CodingKey {
            case name, size, type, subtype, alignment
            case armorClass = "armor_class"
            case hitPoints = "hit_points"
            case hitDice = "hit_dice"
            case speed, strength, dexterity, constitution, intelligence, wisdom, charisma
            case constitutionSave = "constitution_save"
            case intelligenceSave = "intelligence_save"
            case wisdomSave = "wisdom_save"
            case history, perception
            case damageVulnerabilities = "damage_vulnerabilities"
            case damageResistances = "damage_resistances"
            case damageImmunities = "damage_immunities"
            case conditionImmunities = "condition_immunities"
            case senses, languages
            case challengeRating = "challenge_rating"
            case specialAbilities = "special_abilities"
            case actions
            case legendaryDesc = "legendary_desc"
            case legendaryActions = "legendary_actions"
            case speedJSON = "speed_json"
            case armorDesc = "armor_desc"
            case medicine, religion
            case dexteritySave = "dexterity_save"
            case charismaSave = "charisma_save"
            case stealth, group, persuasion, insight, deception, arcana, athletics, acrobatics
            case strengthSave = "strength_save"
            case reactions, survival, investigation, nature, intimidation, performance
            case animalHandling = "animal_handling"
            case sleightOfHand = "sleight_of_hand"
        }
    }

    // MARK: - Action
    struct Action: Codable {
        let name, desc: String
        let attackBonus: Int?
        let damageDice: String?
        let damageBonus: Int?

        enum CodingKeys: String, CodingKey {
            case name, desc
            case attackBonus = "attack_bonus"
            case damageDice = "damage_dice"
            case damageBonus = "damage_bonus"
        }
    }

    enum Alignment: String, Codable {
        case anyAlignment = "any alignment"
        case anyChaoticAlignment = "any chaotic alignment"
        case anyEvilAlignment = "any evil alignment"
        case anyNonGoodAlignment = "any non-good alignment"
        case anyNonLawfulAlignment = "any non-lawful alignment"
        case chaoticEvil = "chaotic evil"
        case chaoticGood = "chaotic good"
        case chaoticNeutral = "chaotic neutral"
        case lawfulEvil = "lawful evil"
        case lawfulGood = "lawful good"
        case lawfulNeutral = "lawful neutral"
        case neutral = "neutral"
        case neutralEvil = "neutral evil"
        case neutralGood = "neutral good"
        case neutralGood50OrNeutralEvil50 = "neutral good (50%) or neutral evil (50%)"
        case unaligned = "unaligned"
    }

    enum Size: String, Codable {
        case gargantuan = "Gargantuan"
        case huge = "Huge"
        case large = "Large"
        case medium = "Medium"
        case small = "Small"
        case tiny = "Tiny"
    }

    // MARK: - SpeedJSON
    struct SpeedJSON: Codable {
        let walk, swim, fly, burrow: Int?
        let climb: Int?
        let hover: Bool?
        let notes: String?
    }

    enum TypeEnum: String, Codable {
        case aberration = "aberration"
        case beast = "beast"
        case celestial = "celestial"
        case construct = "construct"
        case dragon = "dragon"
        case elemental = "elemental"
        case fey = "fey"
        case fiend = "fiend"
        case giant = "giant"
        case humanoid = "humanoid"
        case monstrosity = "monstrosity"
        case ooze = "ooze"
        case plant = "plant"
        case swarmOfTinyBeasts = "swarm of Tiny beasts"
        case undead = "undead"
    }

    public struct Spell: Codable {
        let name, desc: String
        let higherLevel: String?
        let page, range, components: String
        let material: String?
        let ritual, duration, concentration, castingTime: String
        let level: String
        let levelInt: Int
        let school, spellClass: String
        let archetype, circles, domains, oaths: String?
        let patrons: String?

        enum CodingKeys: String, CodingKey {
            case name, desc
            case higherLevel = "higher_level"
            case page, range, components, material, ritual, duration, concentration
            case castingTime = "casting_time"
            case level
            case levelInt = "level_int"
            case school
            case spellClass = "class"
            case archetype, circles, domains, oaths, patrons
        }
    }

}
