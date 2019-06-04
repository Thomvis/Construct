//
//  DDBModels.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

enum DDB {
    // This file was generated from JSON Schema using quicktype, do not modify it directly.
    // To parse the JSON, add this file to your project and do:
    //
    //   let characterSheet = try? newJSONDecoder().decode(CharacterSheet.self, from: jsonData)

    // https://app.quicktype.io?share=kVfCiLlUpO90hvYkmZDY

    // MARK: - CharacterSheet
    struct CharacterSheet: Codable {
        let id: Int
        let readonlyURL: String
        let avatarURL, frameAvatarURL, backdropAvatarURL, smallBackdropAvatarURL: String
        let largeBackdropAvatarURL, thumbnailBackdropAvatarURL: String
        let defaultBackdrop: DefaultBackdrop
        let avatarID: Int?
        let frameAvatarID, backdropAvatarID, smallBackdropAvatarID: String?
        let largeBackdropAvatarID, thumbnailAvatarID, themeColorID, themeColor: String?
        let name: String
        let socialName: String?
        let gender: String?
        let faith: String?
        let age: Int?
        let hair, eyes, skin, height: String?
        let weight: Int?
        let inspiration: Bool
        let baseHitPoints: Int
        let bonusHitPoints, overrideHitPoints: Int?
        let removedHitPoints, temporaryHitPoints, currentXP: Int
        let alignmentID: Int?
        let lifestyleID: Int?
        let stats, bonusStats, overrideStats: [Stat]
        let background: CharacterSheetBackground
        let race: CharacterSheetRace
        let notes: Notes
        let traits: Traits
        let preferences: Preferences
        let lifestyle: JSONNull?
        let inventory: [Inventory]
        let currencies: Currencies
        let classes: [CharacterSheetClass]
        let feats, customDefenseAdjustments, customSenses, customSpeeds: [JSONAny]
        let customProficiencies: [JSONAny]
        let spellDefenses: JSONNull?
        let customActions: [JSONAny]
        let characterValues: [CharacterValue]
        let conditions: [JSONAny]
        let deathSaves: DeathSaves
        let adjustmentXP: JSONNull?
        let spellSlots, pactMagic: [PactMagic]
        let activeSourceCategories: [Int]
        let spells: Spells
        let options: Options
        let choices: Choices
        let actions: Actions
        let modifiers: Modifiers
        let classSpells: [ClassSpell]
        let customItems: [CustomItem]
        let campaign: Campaign?
        let creatures, vehicles, components: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case id
            case readonlyURL = "readonlyUrl"
            case avatarURL = "avatarUrl"
            case frameAvatarURL = "frameAvatarUrl"
            case backdropAvatarURL = "backdropAvatarUrl"
            case smallBackdropAvatarURL = "smallBackdropAvatarUrl"
            case largeBackdropAvatarURL = "largeBackdropAvatarUrl"
            case thumbnailBackdropAvatarURL = "thumbnailBackdropAvatarUrl"
            case defaultBackdrop
            case avatarID = "avatarId"
            case frameAvatarID = "frameAvatarId"
            case backdropAvatarID = "backdropAvatarId"
            case smallBackdropAvatarID = "smallBackdropAvatarId"
            case largeBackdropAvatarID = "largeBackdropAvatarId"
            case thumbnailAvatarID = "thumbnailAvatarId"
            case themeColorID = "themeColorId"
            case themeColor, name, socialName, gender, faith, age, hair, eyes, skin, height, weight, inspiration, baseHitPoints, bonusHitPoints, overrideHitPoints, removedHitPoints, temporaryHitPoints
            case currentXP = "currentXp"
            case alignmentID = "alignmentId"
            case lifestyleID = "lifestyleId"
            case stats, bonusStats, overrideStats, background, race, notes, traits, preferences, lifestyle, inventory, currencies, classes, feats, customDefenseAdjustments, customSenses, customSpeeds, customProficiencies, spellDefenses, customActions, characterValues, conditions, deathSaves
            case adjustmentXP = "adjustmentXp"
            case spellSlots, pactMagic, activeSourceCategories, spells, options, choices, actions, modifiers, classSpells, customItems, campaign, creatures, vehicles, components
        }
    }

    // MARK: - Actions
    struct Actions: Codable {
        let race, actionsClass: [RaceElement]
        let feat: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case race
            case actionsClass = "class"
            case feat
        }
    }

    // MARK: - RaceElement
    struct RaceElement: Codable {
        let id, entityTypeID: Int
        let limitedUse: ClassLimitedUse?
        let name: String
        let classDescription: String?
        let snippet: String
        let abilityModifierStatID: Int?
        let onMissDescription, saveFailDescription, saveSuccessDescription: String?
        let saveStatID: Int?
        let fixedSaveDc, attackTypeRange: Int?
        let actionType: Int
        let attackSubtype: Int?
        let dice: Damage?
        let value, damageTypeID: Int?
        let isMartialArts, isProficient: Bool
        let spellRangeType: Int?
        let displayAsAttack: Bool?
        let range: PurpleRange
        let activation: Activation
        let attackCustomData: AttackCustomData
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case limitedUse, name
            case classDescription = "description"
            case snippet
            case abilityModifierStatID = "abilityModifierStatId"
            case onMissDescription, saveFailDescription, saveSuccessDescription
            case saveStatID = "saveStatId"
            case fixedSaveDc, attackTypeRange, actionType, attackSubtype, dice, value
            case damageTypeID = "damageTypeId"
            case isMartialArts, isProficient, spellRangeType, displayAsAttack, range, activation, attackCustomData
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - Activation
    struct Activation: Codable {
        let activationTime, activationType: Int?
    }

    // MARK: - AttackCustomData
    struct AttackCustomData: Codable {
        let name, notes, damageBonus, toHitBonus: JSONNull?
        let toHit, isOffhand, isSilver, isAdamantine: JSONNull?
        let isProficient, saveDcBonus, saveDc, weight: JSONNull?
        let displayAsAttack, cost: JSONNull?
    }

    // MARK: - ClassLimitedUse
    struct ClassLimitedUse: Codable {
        let name: String?
        let statModifierUsesID: Int?
        let resetType, numberUsed, minNumberConsumed, maxNumberConsumed: Int
        let maxUses, limitedUseOperator: Int

        enum CodingKeys: String, CodingKey {
            case name
            case statModifierUsesID = "statModifierUsesId"
            case resetType, numberUsed, minNumberConsumed, maxNumberConsumed, maxUses
            case limitedUseOperator = "operator"
        }
    }

    // MARK: - PurpleRange
    struct PurpleRange: Codable {
        let range: Int?
        let longRange: Int?
        let aoeType: Int?
        let aoeSize: Int?
        let hasAoeSpecialDescription: Bool
    }

    // MARK: - CharacterSheetBackground
    struct CharacterSheetBackground: Codable {
        let hasCustomBackground: Bool
        let definition: BackgroundDefinition
        let customBackground: CustomBackground
    }

    // MARK: - CustomBackground
    struct CustomBackground: Codable {
        let id, entityTypeID: Int
        let name, customBackgroundDescription, featuresBackground, characteristicsBackground: JSONNull?
        let backgroundType: JSONNull?

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case name
            case customBackgroundDescription = "description"
            case featuresBackground, characteristicsBackground, backgroundType
        }
    }

    // MARK: - BackgroundDefinition
    struct BackgroundDefinition: Codable {
        let id, entityTypeID: Int
        let name, definitionDescription, snippet, shortDescription: String
        let skillProficienciesDescription, toolProficienciesDescription, languagesDescription, equipmentDescription: String
        let featureName, featureDescription: String
        let avatarURL, largeAvatarURL: JSONNull?
        let suggestedCharacteristicsDescription: String
        let suggestedProficiencies: [String]
        let suggestedLanguages: [JSONAny]
        let organization: JSONNull?
        let contractsDescription, spellsPreDescription, spellsPostDescription: String
        let personalityTraits, ideals, bonds, flaws: [Bond]

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case name
            case definitionDescription = "description"
            case snippet, shortDescription, skillProficienciesDescription, toolProficienciesDescription, languagesDescription, equipmentDescription, featureName, featureDescription
            case avatarURL = "avatarUrl"
            case largeAvatarURL = "largeAvatarUrl"
            case suggestedCharacteristicsDescription, suggestedProficiencies, suggestedLanguages, organization, contractsDescription, spellsPreDescription, spellsPostDescription, personalityTraits, ideals, bonds, flaws
        }
    }

    // MARK: - Bond
    struct Bond: Codable {
        let id: Int
        let bondDescription: String
        let diceRoll: Int

        enum CodingKeys: String, CodingKey {
            case id
            case bondDescription = "description"
            case diceRoll
        }
    }

    // MARK: - Stat
    struct Stat: Codable {
        let id: Int
        let name: JSONNull?
        let value: Int?
    }

    // MARK: - CharacterValue
    struct CharacterValue: Codable {
        let typeID: Int
        let value: JSONAny
        let notes: JSONNull?
        let valueID, valueTypeID: Int
        let contextID, contextTypeID: JSONNull?

        enum CodingKeys: String, CodingKey {
            case typeID = "typeId"
            case value, notes
            case valueID = "valueId"
            case valueTypeID = "valueTypeId"
            case contextID = "contextId"
            case contextTypeID = "contextTypeId"
        }
    }

    // MARK: - Campaign
    struct Campaign: Codable {
        let name, campaignDescription, link, publicNotes: String
        let dmUserID: Int
        let dmUsername: String
        let characters: [Character]

        enum CodingKeys: String, CodingKey {
            case name
            case campaignDescription = "description"
            case link, publicNotes
            case dmUserID = "dmUserId"
            case dmUsername, characters
        }
    }

    // MARK: - Character
    struct Character: Codable {
        let userID: Int
        let username: String
        let characterID: Int
        let characterName, characterURL: String
        let avatarURL: String
        let privacyType: Int

        enum CodingKeys: String, CodingKey {
            case userID = "userId"
            case username
            case characterID = "characterId"
            case characterName
            case characterURL = "characterUrl"
            case avatarURL = "avatarUrl"
            case privacyType
        }
    }

    // MARK: - Choices
    struct Choices: Codable {
        let race: [JSONAny]
        let choicesClass, background: [ChoicesBackground]
        let feat: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case race
            case choicesClass = "class"
            case background, feat
        }
    }

    // MARK: - ChoicesBackground
    struct ChoicesBackground: Codable {
        let id: String
        let parentChoiceID: String?
        let type: Int
        let subType, optionValue: Int?
        let label: String?
        let isOptional, isInfinite: Bool
        let defaultSubtypes: [String]
        let options: [Option]
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case id
            case parentChoiceID = "parentChoiceId"
            case type, subType, optionValue, label, isOptional, isInfinite, defaultSubtypes, options
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - Option
    struct Option: Codable {
        let id: Int
        let label: String
        let optionDescription: String?

        enum CodingKeys: String, CodingKey {
            case id, label
            case optionDescription = "description"
        }
    }

    // MARK: - ClassSpell
    struct ClassSpell: Codable {
        let entityTypeID, characterClassID: Int
        let spells: [Spell]

        enum CodingKeys: String, CodingKey {
            case entityTypeID = "entityTypeId"
            case characterClassID = "characterClassId"
            case spells
        }
    }

    // MARK: - Spell
    struct Spell: Codable {
        let id, entityTypeID: Int
        let definition: SpellDefinition
        let prepared, countsAsKnownSpell, usesSpellSlot: Bool
        let castAtLevel: JSONNull?
        let alwaysPrepared: Bool
        let restriction, spellCastingAbilityID, displayAsAttack, additionalDescription: JSONNull?
        let castOnlyAsRitual: Bool
        let ritualCastingType: Int?
        let range: DefinitionRange
        let activation: Activation
        let baseLevelAtWill: Bool
        let atWillLimitedUseLevel: JSONNull?
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case definition, prepared, countsAsKnownSpell, usesSpellSlot, castAtLevel, alwaysPrepared, restriction
            case spellCastingAbilityID = "spellCastingAbilityId"
            case displayAsAttack, additionalDescription, castOnlyAsRitual, ritualCastingType, range, activation, baseLevelAtWill, atWillLimitedUseLevel
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - SpellDefinition
    struct SpellDefinition: Codable {
        let id: Int
        let name: String
        let level: Int
        let school: String
        let duration: Duration
        let activation: Activation
        let range: DefinitionRange
        let asPartOfWeaponAttack: Bool
        let definitionDescription, snippet: String
        let concentration, ritual: Bool
        let rangeArea, damageEffect: JSONNull?
        let components: [Int]
        let componentsDescription: String
        let saveDcAbilityID: Int?
        let healing, healingDice, tempHPDice: String?
        let attackType: Int?
        let canCastAtHigherLevel, isHomebrew: Bool
        let version: String?
        let sourceID, sourcePageNumber: Int?
        let requiresSavingThrow, requiresAttackRoll: Bool
        let atHigherLevels: AtHigherLevels
        let modifiers: [Modifier]
        let conditions: [Condition]
        let tags: [String]
        let castingTimeDescription: String

        enum CodingKeys: String, CodingKey {
            case id, name, level, school, duration, activation, range, asPartOfWeaponAttack
            case definitionDescription = "description"
            case snippet, concentration, ritual, rangeArea, damageEffect, components, componentsDescription
            case saveDcAbilityID = "saveDcAbilityId"
            case healing, healingDice
            case tempHPDice = "tempHpDice"
            case attackType, canCastAtHigherLevel, isHomebrew, version
            case sourceID = "sourceId"
            case sourcePageNumber, requiresSavingThrow, requiresAttackRoll, atHigherLevels, modifiers, conditions, tags, castingTimeDescription
        }
    }

    // MARK: - AtHigherLevels
    struct AtHigherLevels: Codable {
        let scaleType: String?
        let higherLevelDefinitions: [HigherLevelDefinition]
        let additionalAttacks: [AdditionalAttack]
        let additionalTargets, areaOfEffect, duration, creatures: [JSONAny]
        let special: [JSONAny]
        let points: [Point]
    }

    // MARK: - AdditionalAttack
    struct AdditionalAttack: Codable {
        let totalCount, level: Int
        let additionalAttackDescription: String

        enum CodingKeys: String, CodingKey {
            case totalCount, level
            case additionalAttackDescription = "description"
        }
    }

    // MARK: - HigherLevelDefinition
    struct HigherLevelDefinition: Codable {
        let level, typeID: Int
        let dice: Damage?
        let value: Int?
        let details: String

        enum CodingKeys: String, CodingKey {
            case level
            case typeID = "typeId"
            case dice, value, details
        }
    }

    // MARK: - Damage
    struct Damage: Codable {
        let diceCount, diceValue, diceMultiplier, fixedValue: Int?
        let diceString: String?
    }

    // MARK: - Point
    struct Point: Codable {
        let die: Damage
        let level: Int
        let pointDescription: String

        enum CodingKeys: String, CodingKey {
            case die, level
            case pointDescription = "description"
        }
    }

    // MARK: - Condition
    struct Condition: Codable {
        let type, conditionID, conditionDuration: Int
        let durationUnit, exception: String

        enum CodingKeys: String, CodingKey {
            case type
            case conditionID = "conditionId"
            case conditionDuration, durationUnit, exception
        }
    }

    // MARK: - Duration
    struct Duration: Codable {
        let durationInterval: Int?
        let durationUnit: String?
        let durationType: String
    }

    // MARK: - Modifier
    struct Modifier: Codable {
        let id, type, subType: String
        let die: Damage
        let count, duration: Int
        let durationUnit: JSONNull?
        let restriction, friendlyTypeName, friendlySubtypeName: String
        let usePrimaryStat: Bool
        let atHigherLevels: AtHigherLevels
    }

    // MARK: - DefinitionRange
    struct DefinitionRange: Codable {
        let origin: Origin
        let rangeValue: Int?
        let aoeType: String?
        let aoeValue: Int?
    }

    enum Origin: String, Codable {
        case originSelf = "Self"
        case ranged = "Ranged"
        case touch = "Touch"
        case sight = "Sight"
    }

    // MARK: - CharacterSheetClass
    struct CharacterSheetClass: Codable {
        let id, entityTypeID, level: Int
        let isStartingClass: Bool
        let hitDiceUsed: Int
        let definition, subclassDefinition: SubclassDefinitionClass
        let classFeatures: [ClassClassFeature]

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case level, isStartingClass, hitDiceUsed, definition, subclassDefinition, classFeatures
        }
    }

    // MARK: - ClassClassFeature
    struct ClassClassFeature: Codable {
        let definition: ClassFeatureDefinition
        let levelScale: LevelScale?
    }

    struct LevelScale: Codable {
        let id: Int
        let level: Int
        let description: String
        let dice: Damage?
        let fixedValue: Int?
    }

    // MARK: - ClassFeatureDefinition
    struct ClassFeatureDefinition: Codable {
        let id, entityTypeID: Int
        let displayOrder: Int?
        let name, definitionDescription: String
        let snippet: String?
        let activation: Activation
        let multiClassDescription: String?
        let requiredLevel: Int?
        let isSubClassFeature: Bool?
        let limitedUse: [LimitedUseElement]?
        let hideInBuilder, hideInSheet: Bool
        let sourceID, sourcePageNumber: Int?
        let creatureRules: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case displayOrder, name
            case definitionDescription = "description"
            case snippet, activation, multiClassDescription, requiredLevel, isSubClassFeature, limitedUse, hideInBuilder, hideInSheet
            case sourceID = "sourceId"
            case sourcePageNumber, creatureRules
        }
    }

    // MARK: - LimitedUseElement
    struct LimitedUseElement: Codable {
        let level: Int?
        let uses: Int
    }

    // MARK: - SubclassDefinitionClass
    struct SubclassDefinitionClass: Codable {
        let id: Int
        let name, definitionDescription: String
        let equipmentDescription: String?
        let parentClassID: Int?
        let avatarURL, largeAvatarURL: String?
        let portraitAvatarURL: String?
        let moreDetailsURL: String
        let spellCastingAbilityID: Int?
        let sourceIDS: [Int]
        let hitDice: Int
        let classFeatures: [DefinitionClassFeature]
        let wealthDice: Damage?
        let canCastSpells: Bool
        let knowsAllSpells: Bool?
        let spellPrepareType: Int?
        let spellContainerName: String?
        let sourceID: Int
        let sourcePageNumber: Int?

        enum CodingKeys: String, CodingKey {
            case id, name
            case definitionDescription = "description"
            case equipmentDescription
            case parentClassID = "parentClassId"
            case avatarURL = "avatarUrl"
            case largeAvatarURL = "largeAvatarUrl"
            case portraitAvatarURL = "portraitAvatarUrl"
            case moreDetailsURL = "moreDetailsUrl"
            case spellCastingAbilityID = "spellCastingAbilityId"
            case sourceIDS = "sourceIds"
            case hitDice, classFeatures, wealthDice, canCastSpells, knowsAllSpells, spellPrepareType, spellContainerName
            case sourceID = "sourceId"
            case sourcePageNumber
        }
    }

    // MARK: - DefinitionClassFeature
    struct DefinitionClassFeature: Codable {
        let id: Int
        let name: String
        let prerequisite: JSONNull?
        let classFeatureDescription: String
        let requiredLevel: Int
        let displayOrder: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, prerequisite
            case classFeatureDescription = "description"
            case requiredLevel, displayOrder
        }
    }

    // MARK: - Currencies
    struct Currencies: Codable {
        let cp, sp, gp, ep: Int
        let pp: Int
    }

    // MARK: - CustomItem
    struct CustomItem: Codable {
        let id: Int
        let name: String
        let customItemDescription: String?
        let weight, cost: JSONNull?
        let quantity: Int
        let notes: JSONNull?

        enum CodingKeys: String, CodingKey {
            case id, name
            case customItemDescription = "description"
            case weight, cost, quantity, notes
        }
    }

    // MARK: - DeathSaves
    struct DeathSaves: Codable {
        let failCount, successCount: Int?
        let isStabilized: Bool
    }

    // MARK: - DefaultBackdrop
    struct DefaultBackdrop: Codable {
        let backdropAvatarURL, smallBackdropAvatarURL, largeBackdropAvatarURL, thumbnailBackdropAvatarURL: String

        enum CodingKeys: String, CodingKey {
            case backdropAvatarURL = "backdropAvatarUrl"
            case smallBackdropAvatarURL = "smallBackdropAvatarUrl"
            case largeBackdropAvatarURL = "largeBackdropAvatarUrl"
            case thumbnailBackdropAvatarURL = "thumbnailBackdropAvatarUrl"
        }
    }

    // MARK: - Inventory
    struct Inventory: Codable {
        let id, entityTypeID: Int
        let definition: InventoryDefinition
        let quantity: Int
        let isAttuned: Bool?
        let equipped: Bool
        let limitedUse: InventoryLimitedUse?
        let displayAsAttack: JSONNull?

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case definition, quantity, isAttuned, equipped, limitedUse, displayAsAttack
        }
    }

    // MARK: - InventoryDefinition
    struct InventoryDefinition: Codable {
        let baseItemID: Int?
        let baseArmorName: String?
        let strengthRequirement: Int?
        let armorClass, stealthCheck: Int?
        let id, baseTypeID, entityTypeID: Int
        let canEquip, magic: Bool
        let name: String
        let snippet: String?
        let weight: Double
        let type, definitionDescription: String
        let canAttune: Bool
        let attunementDescription: String?
        let rarity: Rarity
        let isHomebrew: Bool
        let version: String?
        let sourceID, sourcePageNumber: Int?
        let stackable: Bool
        let bundleSize: Int
        let avatarURL, largeAvatarURL: String?
        let filterType: String
        let cost: Double?
        let isPack: Bool
        let tags: [String]
        let grantedModifiers: [ItemElement]
        let damage: Damage?
        let damageType: String?
        let fixedDamage: JSONNull?
        let properties: [Property]?
        let attackType, categoryID, range, longRange: Int?
        let isMonkWeapon: Bool?
        let weaponBehaviors: [JSONAny]?
        let subType: String?
        let isConsumable: Bool?

        enum CodingKeys: String, CodingKey {
            case baseItemID = "baseItemId"
            case baseArmorName, strengthRequirement, armorClass, stealthCheck, id
            case baseTypeID = "baseTypeId"
            case entityTypeID = "entityTypeId"
            case canEquip, magic, name, snippet, weight, type
            case definitionDescription = "description"
            case canAttune, attunementDescription, rarity, isHomebrew, version
            case sourceID = "sourceId"
            case sourcePageNumber, stackable, bundleSize
            case avatarURL = "avatarUrl"
            case largeAvatarURL = "largeAvatarUrl"
            case filterType, cost, isPack, tags, grantedModifiers, damage, damageType, fixedDamage, properties, attackType
            case categoryID = "categoryId"
            case range, longRange, isMonkWeapon, weaponBehaviors, subType, isConsumable
        }
    }

    // MARK: - ItemElement
    struct ItemElement: Codable {
        let id: String
        let entityID, entityTypeID: Int?
        let type, subType: String
        let dice: Damage?
        let restriction: String?
        let statID: Int?
        let requiresAttunement: Bool
        let duration: JSONNull?
        let friendlyTypeName, friendlySubtypeName: String
        let isGranted: Bool
        let bonusTypes: [JSONAny]
        let value: Int?
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case id
            case entityID = "entityId"
            case entityTypeID = "entityTypeId"
            case type, subType, dice, restriction
            case statID = "statId"
            case requiresAttunement, duration, friendlyTypeName, friendlySubtypeName, isGranted, bonusTypes, value
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - Property
    struct Property: Codable {
        let id: Int
        let name, propertyDescription: String
        let notes: JSONNull?

        enum CodingKeys: String, CodingKey {
            case id, name
            case propertyDescription = "description"
            case notes
        }
    }

    enum Rarity: String, Codable {
        case common = "Common"
        case uncommon = "Uncommon"
    }

    // MARK: - InventoryLimitedUse
    struct InventoryLimitedUse: Codable {
        let maxUses, numberUsed: Int
        let resetType, resetTypeDescription: String
    }

    // MARK: - Modifiers
    struct Modifiers: Codable {
        let race, modifiersClass, background, item, feat: [ItemElement]
        let condition: [JSONAny]

        var all: [ItemElement] {
            return race + modifiersClass + background + item + feat
        }

        enum CodingKeys: String, CodingKey {
            case race
            case modifiersClass = "class"
            case background, item, feat, condition
        }
    }

    // MARK: - Notes
    struct Notes: Codable {
        let allies: String?
        let personalPossessions: String
        let otherHoldings, organizations, enemies: String?
        let backstory: String?
        let otherNotes: String?
    }

    // MARK: - Options
    struct Options: Codable {
        let race: [JSONAny]
        let optionsClass: [OptionsClass]
        let feat: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case race
            case optionsClass = "class"
            case feat
        }
    }

    // MARK: - OptionsClass
    struct OptionsClass: Codable {
        let definition: PurpleDefinition
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case definition
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - PurpleDefinition
    struct PurpleDefinition: Codable {
        let id, entityTypeID: Int
        let name, definitionDescription, snippet: String
        let activation: Activation
        let sourceID, sourcePageNumber: Int?
        let creatureRules: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case id
            case entityTypeID = "entityTypeId"
            case name
            case definitionDescription = "description"
            case snippet, activation
            case sourceID = "sourceId"
            case sourcePageNumber, creatureRules
        }
    }

    // MARK: - PactMagic
    struct PactMagic: Codable {
        let level, used, available: Int
    }

    // MARK: - Preferences
    struct Preferences: Codable {
        let useHomebrewContent: Bool
        let progressionType, encumbranceType: Int
        let ignoreCoinWeight: Bool
        let hitPointType: Int
        let showUnarmedStrike, showCompanions, showWildShape: Bool
        let primarySense, primaryMovement, privacyType, sharingType: Int
        let abilityScoreDisplayType: Int
        let enforceFeatRules, enforceMulticlassRules: Bool
    }

    // MARK: - CharacterSheetRace
    struct CharacterSheetRace: Codable {
        let entityRaceID, entityRaceTypeID: Int
        let fullName: String
        let baseRaceID, baseRaceTypeID: Int
        let raceDescription: String
        let avatarURL, largeAvatarURL: String?
        let portraitAvatarURL: String
        let moreDetailsURL: String
        let isHomebrew: Bool
        let sourceIDS, groupIDS: [Int]
        let type: Int
        let baseName: String
        let subRaceShortName: String?
        let racialTraits: [RacialTrait]
        let weightSpeeds: WeightSpeeds
        let featIDS: [JSONAny]
        let size: String
        let sizeID: Int

        enum CodingKeys: String, CodingKey {
            case entityRaceID = "entityRaceId"
            case entityRaceTypeID = "entityRaceTypeId"
            case fullName
            case baseRaceID = "baseRaceId"
            case baseRaceTypeID = "baseRaceTypeId"
            case raceDescription = "description"
            case avatarURL = "avatarUrl"
            case largeAvatarURL = "largeAvatarUrl"
            case portraitAvatarURL = "portraitAvatarUrl"
            case moreDetailsURL = "moreDetailsUrl"
            case isHomebrew
            case sourceIDS = "sourceIds"
            case groupIDS = "groupIds"
            case type, subRaceShortName, baseName, racialTraits, weightSpeeds
            case featIDS = "featIds"
            case size
            case sizeID = "sizeId"
        }
    }

    // MARK: - RacialTrait
    struct RacialTrait: Codable {
        let definition: ClassFeatureDefinition
    }

    // MARK: - WeightSpeeds
    struct WeightSpeeds: Codable {
        let normal: Normal
        let encumbered, heavilyEncumbered, pushDragLift, weightSpeedsOverride: JSONNull?

        enum CodingKeys: String, CodingKey {
            case normal, encumbered, heavilyEncumbered, pushDragLift
            case weightSpeedsOverride = "override"
        }
    }

    // MARK: - Normal
    struct Normal: Codable {
        let walk, fly, burrow, swim: Int
        let climb: Int
    }

    // MARK: - Spells
    struct Spells: Codable {
        let race: [SpellsRace]
        let spellsClass: [SpellsClass]
        let item, feat: [JSONAny]

        enum CodingKeys: String, CodingKey {
            case race
            case spellsClass = "class"
            case item, feat
        }
    }

    // MARK: - SpellsRace
    struct SpellsRace: Codable {
        let overrideSaveDc: Int?
        //let limitedUse: LimitedUseElement? FIXME
        let id, entityTypeID: Int
        let definition: SpellDefinition
        let prepared: JSONNull?
        let countsAsKnownSpell, usesSpellSlot: Bool
        let castAtLevel: Int?
        let alwaysPrepared: Bool?
        let restriction: String
        let spellCastingAbilityID: Int
        let displayAsAttack: Bool?
        let additionalDescription: JSONNull?
        let castOnlyAsRitual: Bool
        let ritualCastingType: Int?
        let range: DefinitionRange
        let activation: Activation
        let baseLevelAtWill: Bool
        let atWillLimitedUseLevel: JSONNull?
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case overrideSaveDc, /* limitedUse ,*/ id
            case entityTypeID = "entityTypeId"
            case definition, prepared, countsAsKnownSpell, usesSpellSlot, castAtLevel, alwaysPrepared, restriction
            case spellCastingAbilityID = "spellCastingAbilityId"
            case displayAsAttack, additionalDescription, castOnlyAsRitual, ritualCastingType, range, activation, baseLevelAtWill, atWillLimitedUseLevel
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - SpellsClass
    struct SpellsClass: Codable {
        let overrideSaveDc, limitedUse: JSONNull?
        let id, entityTypeID: Int
        let definition: SpellDefinition
        let prepared: JSONNull?
        let countsAsKnownSpell, usesSpellSlot: Bool
        let castAtLevel, alwaysPrepared: JSONNull?
        let restriction: String
        let spellCastingAbilityID: JSONNull?
        let displayAsAttack: Bool
        let additionalDescription: String?
        let castOnlyAsRitual: Bool
        let ritualCastingType: Int?
        let range: DefinitionRange
        let activation: Activation
        let baseLevelAtWill: Bool
        let atWillLimitedUseLevel: JSONNull?
        let componentID, componentTypeID: Int

        enum CodingKeys: String, CodingKey {
            case overrideSaveDc, limitedUse, id
            case entityTypeID = "entityTypeId"
            case definition, prepared, countsAsKnownSpell, usesSpellSlot, castAtLevel, alwaysPrepared, restriction
            case spellCastingAbilityID = "spellCastingAbilityId"
            case displayAsAttack, additionalDescription, castOnlyAsRitual, ritualCastingType, range, activation, baseLevelAtWill, atWillLimitedUseLevel
            case componentID = "componentId"
            case componentTypeID = "componentTypeId"
        }
    }

    // MARK: - Traits
    struct Traits: Codable {
        let personalityTraits, ideals, bonds, flaws, appearance: String?
    }

    // MARK: - Encode/decode helpers

    class JSONNull: Codable, Hashable {

        public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
            return true
        }

        public var hashValue: Int {
            return 0
        }

        public func hash(into hasher: inout Hasher) {
            // No-op
        }

        public init() {}

        public required init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if !container.decodeNil() {
                throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    class JSONCodingKey: CodingKey {
        let key: String

        required init?(intValue: Int) {
            return nil
        }

        required init?(stringValue: String) {
            key = stringValue
        }

        var intValue: Int? {
            return nil
        }

        var stringValue: String {
            return key
        }
    }

    class JSONAny: Codable {

        let value: Any

        static func decodingError(forCodingPath codingPath: [CodingKey]) -> DecodingError {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode JSONAny")
            return DecodingError.typeMismatch(JSONAny.self, context)
        }

        static func encodingError(forValue value: Any, codingPath: [CodingKey]) -> EncodingError {
            let context = EncodingError.Context(codingPath: codingPath, debugDescription: "Cannot encode JSONAny")
            return EncodingError.invalidValue(value, context)
        }

        static func decode(from container: SingleValueDecodingContainer) throws -> Any {
            if let value = try? container.decode(Bool.self) {
                return value
            }
            if let value = try? container.decode(Int64.self) {
                return value
            }
            if let value = try? container.decode(Double.self) {
                return value
            }
            if let value = try? container.decode(String.self) {
                return value
            }
            if container.decodeNil() {
                return JSONNull()
            }
            throw decodingError(forCodingPath: container.codingPath)
        }

        static func decode(from container: inout UnkeyedDecodingContainer) throws -> Any {
            if let value = try? container.decode(Bool.self) {
                return value
            }
            if let value = try? container.decode(Int64.self) {
                return value
            }
            if let value = try? container.decode(Double.self) {
                return value
            }
            if let value = try? container.decode(String.self) {
                return value
            }
            if let value = try? container.decodeNil() {
                if value {
                    return JSONNull()
                }
            }
            if var container = try? container.nestedUnkeyedContainer() {
                return try decodeArray(from: &container)
            }
            if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self) {
                return try decodeDictionary(from: &container)
            }
            throw decodingError(forCodingPath: container.codingPath)
        }

        static func decode(from container: inout KeyedDecodingContainer<JSONCodingKey>, forKey key: JSONCodingKey) throws -> Any {
            if let value = try? container.decode(Bool.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(Int64.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(Double.self, forKey: key) {
                return value
            }
            if let value = try? container.decode(String.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeNil(forKey: key) {
                if value {
                    return JSONNull()
                }
            }
            if var container = try? container.nestedUnkeyedContainer(forKey: key) {
                return try decodeArray(from: &container)
            }
            if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key) {
                return try decodeDictionary(from: &container)
            }
            throw decodingError(forCodingPath: container.codingPath)
        }

        static func decodeArray(from container: inout UnkeyedDecodingContainer) throws -> [Any] {
            var arr: [Any] = []
            while !container.isAtEnd {
                let value = try decode(from: &container)
                arr.append(value)
            }
            return arr
        }

        static func decodeDictionary(from container: inout KeyedDecodingContainer<JSONCodingKey>) throws -> [String: Any] {
            var dict = [String: Any]()
            for key in container.allKeys {
                let value = try decode(from: &container, forKey: key)
                dict[key.stringValue] = value
            }
            return dict
        }

        static func encode(to container: inout UnkeyedEncodingContainer, array: [Any]) throws {
            for value in array {
                if let value = value as? Bool {
                    try container.encode(value)
                } else if let value = value as? Int64 {
                    try container.encode(value)
                } else if let value = value as? Double {
                    try container.encode(value)
                } else if let value = value as? String {
                    try container.encode(value)
                } else if value is JSONNull {
                    try container.encodeNil()
                } else if let value = value as? [Any] {
                    var container = container.nestedUnkeyedContainer()
                    try encode(to: &container, array: value)
                } else if let value = value as? [String: Any] {
                    var container = container.nestedContainer(keyedBy: JSONCodingKey.self)
                    try encode(to: &container, dictionary: value)
                } else {
                    throw encodingError(forValue: value, codingPath: container.codingPath)
                }
            }
        }

        static func encode(to container: inout KeyedEncodingContainer<JSONCodingKey>, dictionary: [String: Any]) throws {
            for (key, value) in dictionary {
                let key = JSONCodingKey(stringValue: key)!
                if let value = value as? Bool {
                    try container.encode(value, forKey: key)
                } else if let value = value as? Int64 {
                    try container.encode(value, forKey: key)
                } else if let value = value as? Double {
                    try container.encode(value, forKey: key)
                } else if let value = value as? String {
                    try container.encode(value, forKey: key)
                } else if value is JSONNull {
                    try container.encodeNil(forKey: key)
                } else if let value = value as? [Any] {
                    var container = container.nestedUnkeyedContainer(forKey: key)
                    try encode(to: &container, array: value)
                } else if let value = value as? [String: Any] {
                    var container = container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key)
                    try encode(to: &container, dictionary: value)
                } else {
                    throw encodingError(forValue: value, codingPath: container.codingPath)
                }
            }
        }

        static func encode(to container: inout SingleValueEncodingContainer, value: Any) throws {
            if let value = value as? Bool {
                try container.encode(value)
            } else if let value = value as? Int64 {
                try container.encode(value)
            } else if let value = value as? Double {
                try container.encode(value)
            } else if let value = value as? String {
                try container.encode(value)
            } else if value is JSONNull {
                try container.encodeNil()
            } else {
                throw encodingError(forValue: value, codingPath: container.codingPath)
            }
        }

        public required init(from decoder: Decoder) throws {
            if var arrayContainer = try? decoder.unkeyedContainer() {
                self.value = try JSONAny.decodeArray(from: &arrayContainer)
            } else if var container = try? decoder.container(keyedBy: JSONCodingKey.self) {
                self.value = try JSONAny.decodeDictionary(from: &container)
            } else {
                let container = try decoder.singleValueContainer()
                self.value = try JSONAny.decode(from: container)
            }
        }

        public func encode(to encoder: Encoder) throws {
            if let arr = self.value as? [Any] {
                var container = encoder.unkeyedContainer()
                try JSONAny.encode(to: &container, array: arr)
            } else if let dict = self.value as? [String: Any] {
                var container = encoder.container(keyedBy: JSONCodingKey.self)
                try JSONAny.encode(to: &container, dictionary: dict)
            } else {
                var container = encoder.singleValueContainer()
                try JSONAny.encode(to: &container, value: self.value)
            }
        }
    }

}
