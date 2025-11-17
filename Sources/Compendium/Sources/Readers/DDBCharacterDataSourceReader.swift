//
//  DDBCharacterDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import Dice

public class DDBCharacterDataSourceReader: CompendiumDataSourceReader {
    public static let name = "DDBCharacterDataSourceReader"
    
    public var dataSource: any CompendiumDataSource<Data>

    public init(dataSource: any CompendiumDataSource<Data>) {
        self.dataSource = dataSource
    }

    public func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        try dataSource.read().flatMap { data in
            let characterSheet: DDB.CharacterSheet
            do {
                characterSheet = try JSONDecoder().decode(DDB.CharacterSheet.self, from: data)
            } catch {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }

            guard let character = Character(characterSheet: characterSheet, realm: .init(realmId)) else {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }

            return [CompendiumDataSourceReaderOutput.item(character)].async
        }.stream
    }
}

private extension Character {
    init?(characterSheet s: DDB.CharacterSheet, realm: CompendiumItemKey.Realm) {
        guard let stats = StatBlock(characterSheet: s) else { return nil }
        self.init(
            id: UUID().tagged(),
            realm: realm,
            level: s.level,
            stats: stats,
            player: Player(name: nil) // FIXME
        )        
    }
}

private extension StatBlock {
    init?(characterSheet s: DDB.CharacterSheet) {
        guard let size = CreatureSize(englishName: s.race.size) else { return nil }

//        let a = s.classes.map { $0.level.d() }

        self.init(
            name: s.name,
            size: size,
            type: s.race.baseName,
            subtype: s.race.subRaceShortName,
            alignment: s.alignmentID.flatMap(Alignment.init),

            armorClass: s.effectiveArmorClass,
            armor: s.armor,
            hitPointDice: (s.classes.map { $0.level.d($0.definition.hitDice) }.reduce(.number(0), +) + (s.level*s.effectiveAbilityScores.constitution.modifier.modifier)).normalized ?? .number(0),
            hitPoints: s.currentHitPoints,
            movement: s.speeds,

            abilityScores: s.effectiveAbilityScores,

            // FIXME
            savingThrows: [:],
            skills: [:],
            initiative: nil,

            // FIXME
            damageVulnerabilities: nil,
            damageResistances: nil,
            damageImmunities: nil,
            conditionImmunities: nil,

            // FIXME
            senses: nil,
            languages: nil,

            // FIXME
            challengeRating: nil,

            // FIXME
            features: [],
            actions: [],
            reactions: [],
            legendary: nil
        )
    }
}

private extension Alignment {
    init?(_ alignmentId: Int) {
        switch alignmentId {
        case 1: self = .lawfulGood
        case 2: self = .neutralGood
        case 3: self = .chaoticGood
        case 4: self = .lawfulNeutral
        case 5: self = .neutral
        case 6: self = .chaoticNeutral
        case 7: self = .lawfulEvil
        case 8: self = .neutralEvil
        case 9: self = .chaoticEvil
        default: return nil
        }
    }
}

private extension Ability {
    init?(_ abilityId: Int) {
        switch abilityId {
        case 1: self = .strength
        case 2: self = .dexterity
        case 3: self = .constitution
        case 4: self = .intelligence
        case 5: self = .wisdom
        case 6: self = .charisma
        default: return nil
        }
    }
}

extension DDB.CharacterSheet {
    var level: Int {
        return classes.map { $0.level }.reduce(0, +)
    }

    var armor: [Armor] {
        inventory
            .filter { item in item.equipped && item.definition.armorClass != nil }
            .compactMap { item in item.definition.baseArmorName.flatMap(Armor.armor) }
    }

    var effectiveArmorClass: Int {

        let armorItems = armor

        let base = armorItems.compactMap { item -> Int? in
            return item.effectiveArmorClass(effectiveAbilityScores.dexterity)
        }.max() ?? 10 + effectiveAbilityScores.dexterity.modifier.modifier

        let armorBonus = armorItems.compactMap { item in
            return item.armorClass.bonus
        }.reduce(0, +)

        var armorClass = base + armorBonus

        // apply modifiers
        for m in modifiers.all {
            if m.type == "bonus", m.subType == "armor-class", m.isGranted, let value = m.value {
                armorClass += value
            } else if m.type == "set", m.subType == "unarmored-armor-class", armorItems.isEmpty, let value = m.value {
                armorClass = base + value + armorBonus
            }
        }

        return armorClass
    }

    var effectiveAbilityScores: AbilityScores {
        var res = AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10)

        // base
        for baseStat in stats {
            guard let ability = Ability(baseStat.id), let value = baseStat.value else { continue }
            res[ability] = AbilityScore(value)
        }

        // other bonus
        for bonusStat in bonusStats {
            guard let ability = Ability(bonusStat.id), let value = bonusStat.value else { continue }
            res[ability] += value
        }

        // race modifiers
        for modifier in modifiers.all {
            guard let value = modifier.value, modifier.type == "bonus" else { continue }
            switch modifier.subType {
            case "strength-score": res[.strength] += value
            case "dexterity-score": res[.dexterity] += value
            case "constitution-score": res[.constitution] += value
            case "intelligence-score": res[.intelligence] += value
            case "wisdom-score": res[.wisdom] += value
            case "charisma-score": res[.charisma] += value
            default: break
            }
        }

        // overrides
        for statOverride in overrideStats {
            guard let ability = Ability(statOverride.id), let value = statOverride.value else { continue }
            res[ability] = AbilityScore(value)
        }

        return res
    }

    var currentHitPoints: Int {
        return maximumHitPoints + temporaryHitPoints - removedHitPoints
    }

    var maximumHitPoints: Int {
        return overrideHitPoints ?? (baseHitPoints + (level*effectiveAbilityScores.constitution.modifier.modifier) + (bonusHitPoints ?? 0))
    }

    var speeds: [MovementMode: Int] {
        var base: [MovementMode: Int] = [
            .walk: race.weightSpeeds.normal.walk,
            .fly: race.weightSpeeds.normal.fly,
            .swim: race.weightSpeeds.normal.swim,
            .climb: race.weightSpeeds.normal.climb,
            .burrow: race.weightSpeeds.normal.burrow
        ].filter { $0.value > 0 }

        for modifier in modifiers.race {
            guard modifier.type == "set" && modifier.subType == "innate-speed-swimming", let value = modifier.value else { continue }
            base[.swim] = value
        }

        return base
    }
}

extension DDB.Normal {
    var dict: [MovementMode: Int] {
        // FIXME Take into account modifiers
        return [
            .walk: self.walk,
            .fly: self.fly,
            .swim: self.swim,
            .climb: self.climb,
            .burrow: self.burrow
        ].filter { $0.value > 0 }
    }
}
