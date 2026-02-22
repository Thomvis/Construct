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

            // v2
            case subcategory
            case challengeRatingText = "challenge_rating_text"
            case abilityScores = "ability_scores"
            case savingThrows = "saving_throws"
            case skillBonuses = "skill_bonuses"
            case traits
            case resistancesAndImmunities = "resistances_and_immunities"
            case armorDetail = "armor_detail"
            case passivePerception = "passive_perception"
            case normalSightRange = "normal_sight_range"
            case darkvisionRange = "darkvision_range"
            case blindsightRange = "blindsight_range"
            case tremorsenseRange = "tremorsense_range"
            case truesightRange = "truesight_range"
        }

        struct NamedResource: Decodable {
            let name: String
        }

        struct LocalizedString: Decodable {
            let asString: String?

            enum CodingKeys: String, CodingKey {
                case asString = "as_string"
            }
        }

        struct AbilityScoresV2: Decodable {
            let strength, dexterity, constitution, intelligence, wisdom, charisma: Int
        }

        struct ResistancesAndImmunitiesV2: Decodable {
            let damageImmunitiesDisplay: String
            let damageResistancesDisplay: String
            let damageVulnerabilitiesDisplay: String
            let conditionImmunitiesDisplay: String

            enum CodingKeys: String, CodingKey {
                case damageImmunitiesDisplay = "damage_immunities_display"
                case damageResistancesDisplay = "damage_resistances_display"
                case damageVulnerabilitiesDisplay = "damage_vulnerabilities_display"
                case conditionImmunitiesDisplay = "condition_immunities_display"
            }
        }

        struct SpeedV2: Decodable {
            let walk, swim, fly, burrow: Double?
            let climb: Double?
            let hover: Bool?

            func toSpeedJSON() -> SpeedJSON {
                SpeedJSON(
                    walk: walk.map(Self.toInt),
                    swim: swim.map(Self.toInt),
                    fly: fly.map(Self.toInt),
                    burrow: burrow.map(Self.toInt),
                    climb: climb.map(Self.toInt),
                    hover: hover,
                    notes: nil
                )
            }

            static func toInt(_ value: Double) -> Int {
                Int(value.rounded())
            }
        }

        struct V2Action: Decodable {
            enum ActionType: String, Decodable {
                case action = "ACTION"
                case reaction = "REACTION"
                case legendaryAction = "LEGENDARY_ACTION"
                case bonusAction = "BONUS_ACTION"
                case lairAction = "LAIR_ACTION"
            }

            struct UsageLimits: Decodable {
                let type: String
                let param: Int?
            }

            let name: String
            let desc: String
            let actionType: ActionType?
            let orderInStatblock: Int?
            let legendaryActionCost: Int?
            let usageLimits: UsageLimits?
            let limitedToForm: String?

            enum CodingKeys: String, CodingKey {
                case name
                case desc
                case actionType = "action_type"
                case orderInStatblock = "order_in_statblock"
                case legendaryActionCost = "legendary_action_cost"
                case usageLimits = "usage_limits"
                case limitedToForm = "limited_to_form"
            }

            func toAction() -> Action {
                Action(name: decoratedName, desc: desc, attackBonus: nil, damageDice: nil, damageBonus: nil)
            }

            private var decoratedName: String {
                let suffixes = [limitedToFormSuffix, usageSuffix, legendaryCostSuffix].compactMap { $0 }
                guard !suffixes.isEmpty else { return name }
                return "\(name) (\(suffixes.joined(separator: "; ")))"
            }

            // v2 sends structured usage metadata instead of appending these details to the name.
            // We reconstruct the v1-style suffix so existing action parsing stays stable.
            private var usageSuffix: String? {
                guard let usageLimits else { return nil }

                switch usageLimits.type {
                case "PER_DAY":
                    guard let usesPerDay = usageLimits.param else { return nil }
                    return "\(usesPerDay)/day"
                case "RECHARGE_ON_ROLL":
                    guard let rechargeOnRoll = usageLimits.param else { return "Recharge" }
                    if rechargeOnRoll >= 6 {
                        return "Recharge 6"
                    } else {
                        return "Recharge \(rechargeOnRoll)-6"
                    }
                case "RECHARGE_AFTER_REST":
                    return "Recharges after a Short or Long Rest"
                default:
                    return nil
                }
            }

            private var legendaryCostSuffix: String? {
                guard actionType == .legendaryAction, let legendaryActionCost, legendaryActionCost > 1 else {
                    return nil
                }
                return "Costs \(legendaryActionCost) Actions"
            }

            private var limitedToFormSuffix: String? {
                limitedToForm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyString
            }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let isV2Payload = c.contains(.abilityScores) || c.contains(.challengeRatingText) || c.contains(.traits)

            if isV2Payload {
                self.name = try c.decode(String.self, forKey: .name)

                if let sized = try? c.decode(NamedResource.self, forKey: .size) {
                    self.size = sized.name
                } else {
                    self.size = try c.decode(String.self, forKey: .size)
                }

                if let typed = try? c.decode(NamedResource.self, forKey: .type) {
                    self.type = typed.name.lowercased()
                } else {
                    self.type = try c.decode(String.self, forKey: .type).lowercased()
                }

                self.subtype = try c.decodeIfPresent(String.self, forKey: .subcategory)
                    ?? c.decodeIfPresent(String.self, forKey: .subtype)
                    ?? ""
                self.alignment = try c.decodeIfPresent(String.self, forKey: .alignment) ?? "unaligned"

                self.armorClass = try c.decode(Int.self, forKey: .armorClass)
                self.hitPoints = try c.decode(Int.self, forKey: .hitPoints)
                self.hitDice = try c.decodeIfPresent(String.self, forKey: .hitDice)
                    ?? "\(max(self.hitPoints, 1))d1"

                let v2Speed = try c.decodeIfPresent(SpeedV2.self, forKey: .speed)
                let decodedSpeedJSON = v2Speed?.toSpeedJSON()
                self.speedJSON = decodedSpeedJSON
                self.speed = decodedSpeedJSON.map(Either.right) ?? .left("")

                let abilityScores = try c.decode(AbilityScoresV2.self, forKey: .abilityScores)
                self.strength = abilityScores.strength
                self.dexterity = abilityScores.dexterity
                self.constitution = abilityScores.constitution
                self.intelligence = abilityScores.intelligence
                self.wisdom = abilityScores.wisdom
                self.charisma = abilityScores.charisma

                let savingThrows = try c.decodeIfPresent([String: Int].self, forKey: .savingThrows) ?? [:]
                self.strengthSave = savingThrows["strength"]
                self.dexteritySave = savingThrows["dexterity"]
                self.constitutionSave = savingThrows["constitution"]
                self.intelligenceSave = savingThrows["intelligence"]
                self.wisdomSave = savingThrows["wisdom"]
                self.charismaSave = savingThrows["charisma"]

                let skillBonuses = try c.decodeIfPresent([String: Int].self, forKey: .skillBonuses) ?? [:]
                self.acrobatics = skillBonuses["acrobatics"]
                self.animalHandling = skillBonuses["animal_handling"]
                self.arcana = skillBonuses["arcana"]
                self.athletics = skillBonuses["athletics"]
                self.deception = skillBonuses["deception"]
                self.history = skillBonuses["history"]
                self.insight = skillBonuses["insight"]
                self.intimidation = skillBonuses["intimidation"]
                self.investigation = skillBonuses["investigation"]
                self.medicine = skillBonuses["medicine"]
                self.nature = skillBonuses["nature"]
                self.perception = skillBonuses["perception"]
                self.performance = skillBonuses["performance"]
                self.persuasion = skillBonuses["persuasion"]
                self.religion = skillBonuses["religion"]
                self.sleightOfHand = skillBonuses["sleight_of_hand"]
                self.stealth = skillBonuses["stealth"]
                self.survival = skillBonuses["survival"]

                let res = try c.decodeIfPresent(ResistancesAndImmunitiesV2.self, forKey: .resistancesAndImmunities)
                self.damageVulnerabilities = res?.damageVulnerabilitiesDisplay ?? ""
                self.damageResistances = res?.damageResistancesDisplay ?? ""
                self.damageImmunities = res?.damageImmunitiesDisplay ?? ""
                self.conditionImmunities = res?.conditionImmunitiesDisplay ?? ""

                let passivePerception = try c.decodeIfPresent(Int.self, forKey: .passivePerception)
                let normalSightRange = try c.decodeIfPresent(Double.self, forKey: .normalSightRange).map(SpeedV2.toInt)
                let darkvisionRange = try c.decodeIfPresent(Double.self, forKey: .darkvisionRange).map(SpeedV2.toInt)
                let blindsightRange = try c.decodeIfPresent(Double.self, forKey: .blindsightRange).map(SpeedV2.toInt)
                let tremorsenseRange = try c.decodeIfPresent(Double.self, forKey: .tremorsenseRange).map(SpeedV2.toInt)
                let truesightRange = try c.decodeIfPresent(Double.self, forKey: .truesightRange).map(SpeedV2.toInt)
                self.senses = Self.v2Senses(
                    normalSightRange: normalSightRange,
                    darkvisionRange: darkvisionRange,
                    blindsightRange: blindsightRange,
                    tremorsenseRange: tremorsenseRange,
                    truesightRange: truesightRange,
                    passivePerception: passivePerception
                )
                self.languages = (try? c.decode(LocalizedString.self, forKey: .languages))?.asString
                    ?? (try? c.decode(String.self, forKey: .languages))
                    ?? ""
                self.challengeRating = try c.decodeIfPresent(String.self, forKey: .challengeRatingText)
                    ?? c.decodeIfPresent(String.self, forKey: .challengeRating)
                    ?? "0"

                let traits = try c.decodeIfPresent([Action].self, forKey: .traits) ?? []
                self.specialAbilities = traits.isEmpty ? nil : .left(traits)

                let v2Actions = try c.decodeIfPresent([V2Action].self, forKey: .actions) ?? []
                let orderedV2Actions = v2Actions
                    .enumerated()
                    .sorted { lhs, rhs in
                        let lhsOrder = lhs.element.orderInStatblock ?? Int.max
                        let rhsOrder = rhs.element.orderInStatblock ?? Int.max
                        if lhsOrder == rhsOrder {
                            return lhs.offset < rhs.offset
                        }
                        return lhsOrder < rhsOrder
                    }
                    .map(\.element)

                let actionActions = orderedV2Actions.filter { $0.actionType == .action }.map { $0.toAction() }
                let reactionActions = orderedV2Actions.filter { $0.actionType == .reaction }.map { $0.toAction() }
                let legendaryActions = orderedV2Actions.filter { $0.actionType == .legendaryAction }.map { $0.toAction() }

                self.actions = actionActions.isEmpty ? nil : .left(actionActions)
                self.reactions = reactionActions.isEmpty ? nil : .left(reactionActions)
                self.legendaryActions = legendaryActions.isEmpty ? nil : .left(legendaryActions)
                self.legendaryDesc = try c.decodeIfPresent(String.self, forKey: .legendaryDesc)
                    ?? Self.v2LegendaryDescription(creatureName: self.name, hasLegendaryActions: !legendaryActions.isEmpty)

                self.armorDesc = try c.decodeIfPresent(String.self, forKey: .armorDetail)
                    ?? c.decodeIfPresent(String.self, forKey: .armorDesc)
                self.group = try c.decodeIfPresent(String.self, forKey: .group)
            } else {
                self.name = try c.decode(String.self, forKey: .name)
                self.size = try c.decode(String.self, forKey: .size)
                self.type = try c.decode(String.self, forKey: .type)
                self.subtype = try c.decodeIfPresent(String.self, forKey: .subtype) ?? ""
                self.alignment = try c.decode(String.self, forKey: .alignment)
                self.armorClass = try c.decode(Int.self, forKey: .armorClass)
                self.hitPoints = try c.decode(Int.self, forKey: .hitPoints)
                self.hitDice = try c.decodeIfPresent(String.self, forKey: .hitDice)
                    ?? "\(max(self.hitPoints, 1))d1"
                self.speed = try c.decode(Either<String, SpeedJSON>.self, forKey: .speed)
                self.strength = try c.decode(Int.self, forKey: .strength)
                self.dexterity = try c.decode(Int.self, forKey: .dexterity)
                self.constitution = try c.decode(Int.self, forKey: .constitution)
                self.intelligence = try c.decode(Int.self, forKey: .intelligence)
                self.wisdom = try c.decode(Int.self, forKey: .wisdom)
                self.charisma = try c.decode(Int.self, forKey: .charisma)

                self.constitutionSave = try c.decodeIfPresent(Int.self, forKey: .constitutionSave)
                self.intelligenceSave = try c.decodeIfPresent(Int.self, forKey: .intelligenceSave)
                self.wisdomSave = try c.decodeIfPresent(Int.self, forKey: .wisdomSave)
                self.history = try c.decodeIfPresent(Int.self, forKey: .history)
                self.perception = try c.decodeIfPresent(Int.self, forKey: .perception)

                self.damageVulnerabilities = try c.decodeIfPresent(String.self, forKey: .damageVulnerabilities) ?? ""
                self.damageResistances = try c.decodeIfPresent(String.self, forKey: .damageResistances) ?? ""
                self.damageImmunities = try c.decodeIfPresent(String.self, forKey: .damageImmunities) ?? ""
                self.conditionImmunities = try c.decodeIfPresent(String.self, forKey: .conditionImmunities) ?? ""
                self.senses = try c.decodeIfPresent(String.self, forKey: .senses) ?? ""
                self.languages = try c.decodeIfPresent(String.self, forKey: .languages) ?? ""
                self.challengeRating = try c.decodeIfPresent(String.self, forKey: .challengeRating) ?? "0"

                self.specialAbilities = try c.decodeIfPresent(Either<[Action], String>.self, forKey: .specialAbilities)
                self.actions = try c.decodeIfPresent(Either<[Action], String>.self, forKey: .actions)
                self.legendaryDesc = try c.decodeIfPresent(String.self, forKey: .legendaryDesc)
                self.legendaryActions = try c.decodeIfPresent(Either<[Action], String>.self, forKey: .legendaryActions)
                self.speedJSON = try c.decodeIfPresent(SpeedJSON.self, forKey: .speedJSON)
                self.armorDesc = try c.decodeIfPresent(String.self, forKey: .armorDesc)

                self.medicine = try c.decodeIfPresent(Int.self, forKey: .medicine)
                self.religion = try c.decodeIfPresent(Int.self, forKey: .religion)
                self.dexteritySave = try c.decodeIfPresent(Int.self, forKey: .dexteritySave)
                self.charismaSave = try c.decodeIfPresent(Int.self, forKey: .charismaSave)
                self.stealth = try c.decodeIfPresent(Int.self, forKey: .stealth)
                self.group = try c.decodeIfPresent(String.self, forKey: .group)
                self.persuasion = try c.decodeIfPresent(Int.self, forKey: .persuasion)
                self.insight = try c.decodeIfPresent(Int.self, forKey: .insight)
                self.deception = try c.decodeIfPresent(Int.self, forKey: .deception)
                self.arcana = try c.decodeIfPresent(Int.self, forKey: .arcana)
                self.athletics = try c.decodeIfPresent(Int.self, forKey: .athletics)
                self.acrobatics = try c.decodeIfPresent(Int.self, forKey: .acrobatics)
                self.strengthSave = try c.decodeIfPresent(Int.self, forKey: .strengthSave)
                self.reactions = try c.decodeIfPresent(Either<[Action], String>.self, forKey: .reactions)
                self.survival = try c.decodeIfPresent(Int.self, forKey: .survival)
                self.investigation = try c.decodeIfPresent(Int.self, forKey: .investigation)
                self.nature = try c.decodeIfPresent(Int.self, forKey: .nature)
                self.intimidation = try c.decodeIfPresent(Int.self, forKey: .intimidation)
                self.performance = try c.decodeIfPresent(Int.self, forKey: .performance)
                self.animalHandling = try c.decodeIfPresent(Int.self, forKey: .animalHandling)
                self.sleightOfHand = try c.decodeIfPresent(Int.self, forKey: .sleightOfHand)
            }
        }

        private static func v2Senses(
            normalSightRange: Int?,
            darkvisionRange: Int?,
            blindsightRange: Int?,
            tremorsenseRange: Int?,
            truesightRange: Int?,
            passivePerception: Int?
        ) -> String {
            var components: [String] = []

            // v2 splits senses into numeric fields. "normal sight" is generally the default 10560 ft.
            // and is not listed in 5e stat blocks, so we reconstruct only special senses + passive Perception.
            if let blindsightRange, blindsightRange > 0 {
                components.append("blindsight \(blindsightRange) ft.")
            }
            if let darkvisionRange, darkvisionRange > 0 {
                components.append("darkvision \(darkvisionRange) ft.")
            }
            if let tremorsenseRange, tremorsenseRange > 0 {
                components.append("tremorsense \(tremorsenseRange) ft.")
            }
            if let truesightRange, truesightRange > 0 {
                components.append("truesight \(truesightRange) ft.")
            }

            if let passivePerception, passivePerception > 0 {
                components.append("passive Perception \(passivePerception)")
            } else if let normalSightRange, normalSightRange > 0, normalSightRange < 1000 {
                components.append("sight \(normalSightRange) ft.")
            }

            return components.joined(separator: ", ")
        }

        private static func v2LegendaryDescription(creatureName: String, hasLegendaryActions: Bool) -> String? {
            guard hasLegendaryActions else { return nil }

            let lowercasedName = creatureName.lowercased()
            return "The \(lowercasedName) can take 3 legendary actions, choosing from the options below. Only one legendary action option can be used at a time and only at the end of another creature's turn. The \(lowercasedName) regains spent legendary actions at the start of its turn."
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

    public struct Spell: Decodable {
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

            // v2
            case rangeText = "range_text"
            case verbal
            case somatic
            case materialSpecified = "material_specified"
            case classes
            case reactionCondition = "reaction_condition"
        }

        struct NamedResource: Decodable {
            let name: String
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let isV2Payload = c.contains(.verbal) || c.contains(.classes) || c.contains(.rangeText)

            self.name = try c.decode(String.self, forKey: .name)
            self.desc = try c.decode(String.self, forKey: .desc)
            self.higherLevel = try c.decodeIfPresent(String.self, forKey: .higherLevel)

            if isV2Payload {
                self.page = try c.decodeIfPresent(String.self, forKey: .page) ?? ""
                self.range = try c.decodeIfPresent(String.self, forKey: .rangeText)
                    ?? (try? c.decode(String.self, forKey: .range))
                    ?? ""

                let verbal = try c.decodeIfPresent(Bool.self, forKey: .verbal) ?? false
                let somatic = try c.decodeIfPresent(Bool.self, forKey: .somatic) ?? false
                let materialComponent = try c.decodeIfPresent(Bool.self, forKey: .material) ?? false
                self.components = [
                    verbal ? "V" : nil,
                    somatic ? "S" : nil,
                    materialComponent ? "M" : nil,
                ]
                .compactMap { $0 }
                .joined(separator: ", ")

                self.material = try c.decodeIfPresent(String.self, forKey: .materialSpecified)
                    ?? (try? c.decode(String.self, forKey: .material))

                if let ritual = try c.decodeIfPresent(Bool.self, forKey: .ritual) {
                    self.ritual = ritual ? "yes" : "no"
                } else {
                    self.ritual = try c.decodeIfPresent(String.self, forKey: .ritual) ?? "no"
                }

                self.duration = try c.decodeIfPresent(String.self, forKey: .duration) ?? ""

                if let concentration = try c.decodeIfPresent(Bool.self, forKey: .concentration) {
                    self.concentration = concentration ? "yes" : "no"
                } else {
                    self.concentration = try c.decodeIfPresent(String.self, forKey: .concentration) ?? "no"
                }

                let reactionCondition = try c.decodeIfPresent(String.self, forKey: .reactionCondition)?.nonEmptyString
                let rawCastingTime = try c.decodeIfPresent(String.self, forKey: .castingTime) ?? ""
                self.castingTime = Self.normalizeV2CastingTime(rawCastingTime, reactionCondition: reactionCondition)

                if let levelInt = try c.decodeIfPresent(Int.self, forKey: .level) {
                    self.levelInt = levelInt
                } else if let levelString = try c.decodeIfPresent(String.self, forKey: .level),
                    let levelInt = Int(levelString)
                {
                    self.levelInt = levelInt
                } else {
                    self.levelInt = try c.decodeIfPresent(Int.self, forKey: .levelInt) ?? 0
                }
                self.level = String(self.levelInt)

                if let school = try? c.decode(NamedResource.self, forKey: .school) {
                    self.school = school.name
                } else {
                    self.school = try c.decodeIfPresent(String.self, forKey: .school) ?? ""
                }

                let classes = try c.decodeIfPresent([NamedResource].self, forKey: .classes) ?? []
                self.spellClass = if classes.isEmpty {
                    try c.decodeIfPresent(String.self, forKey: .spellClass) ?? ""
                } else {
                    classes.map(\.name).joined(separator: ", ")
                }

                self.archetype = try c.decodeIfPresent(String.self, forKey: .archetype)
                self.circles = try c.decodeIfPresent(String.self, forKey: .circles)
                self.domains = try c.decodeIfPresent(String.self, forKey: .domains)
                self.oaths = try c.decodeIfPresent(String.self, forKey: .oaths)
                self.patrons = try c.decodeIfPresent(String.self, forKey: .patrons)
            } else {
                self.page = try c.decode(String.self, forKey: .page)
                self.range = try c.decode(String.self, forKey: .range)
                self.components = try c.decode(String.self, forKey: .components)
                self.material = try c.decodeIfPresent(String.self, forKey: .material)
                self.ritual = try c.decode(String.self, forKey: .ritual)
                self.duration = try c.decode(String.self, forKey: .duration)
                self.concentration = try c.decode(String.self, forKey: .concentration)
                self.castingTime = try c.decode(String.self, forKey: .castingTime)
                self.level = try c.decode(String.self, forKey: .level)
                self.levelInt = try c.decode(Int.self, forKey: .levelInt)
                self.school = try c.decode(String.self, forKey: .school)
                self.spellClass = try c.decode(String.self, forKey: .spellClass)
                self.archetype = try c.decodeIfPresent(String.self, forKey: .archetype)
                self.circles = try c.decodeIfPresent(String.self, forKey: .circles)
                self.domains = try c.decodeIfPresent(String.self, forKey: .domains)
                self.oaths = try c.decodeIfPresent(String.self, forKey: .oaths)
                self.patrons = try c.decodeIfPresent(String.self, forKey: .patrons)
            }
        }

        private static func normalizeV2CastingTime(_ rawValue: String, reactionCondition: String?) -> String {
            let rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { return rawValue }

            switch rawValue {
            case "action":
                return "1 action"
            case "bonus-action":
                return "1 bonus action"
            case "bonus_action":
                return "1 bonus action"
            case "reaction":
                guard let reactionCondition else { return "1 reaction" }
                if reactionCondition.lowercased().hasPrefix("which ") || reactionCondition.lowercased().hasPrefix("when ") {
                    return "1 reaction, \(reactionCondition)"
                } else {
                    return "1 reaction, which you take \(reactionCondition)"
                }
            case "turn":
                return "1 turn"
            case "round":
                return "1 round"
            case "minute":
                return "1 minute"
            case "hour":
                return "1 hour"
            default:
                let normalizedDurationMap: [String: String] = [
                    "1minute": "1 minute",
                    "5minutes": "5 minutes",
                    "10minutes": "10 minutes",
                    "1hour": "1 hour",
                    "4hours": "4 hours",
                    "7hours": "7 hours",
                    "8hours": "8 hours",
                    "9hours": "9 hours",
                    "12hours": "12 hours",
                    "24hours": "24 hours",
                    "1week": "1 week",
                ]

                return normalizedDurationMap[rawValue] ?? rawValue
            }
        }
    }

}
