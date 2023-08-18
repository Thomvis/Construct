//
//  Open5eDataSourceReader.swift
//  
//
//  Created by Thomas Visser on 16/06/2023.
//

import AsyncAlgorithms
import Dice
import Foundation
import GameModels
import Helpers

public final class Open5eDataSourceReader: CompendiumDataSourceReader {
    public static let name = "Open5eMonsterDataSourceReader"

    public let dataSource: any CompendiumDataSource<[Open5eAPIResult]>
    let generateUUID: () -> UUID

    public init(dataSource: any CompendiumDataSource<[Open5eAPIResult]>, generateUUID: @escaping () -> UUID) {
        self.dataSource = dataSource
        self.generateUUID = generateUUID
    }

    public func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        try dataSource.read().flatMap { items in
            return items.async.map { item in
                switch item {
                case .left(let m):
                    let monster = Monster(open5eMonster: m, realm: .init(realmId), generateUUID: self.generateUUID)
                    guard let monster else { return CompendiumDataSourceReaderOutput.invalidItem(String(describing: m)) }
                    return .item(monster)
                case .right(let s):
                    guard let spell = Spell(open5eSpell: s, realm: .init(realmId)) else { return CompendiumDataSourceReaderOutput.invalidItem(String(describing: s)) }
                    return .item(spell)
                }
            }
        }.stream
    }
}

private extension Monster {
    init?(open5eMonster m: O5e.Monster, realm: CompendiumItemKey.Realm, generateUUID: () -> UUID) {
        self.init(
            realm: realm,
            stats: StatBlock(open5eMonster: m, generateUUID: generateUUID)!,
            challengeRating: Fraction(rawValue: m.challengeRating)!
        )
    }
}

private extension StatBlock {
    init?(open5eMonster m: O5e.Monster, generateUUID: () -> UUID) {
        guard let hitPointDice = DiceExpressionParser.parse(m.hitDice) else { return nil }

        let optionalSkills: [Skill: Modifier?] = [
            .acrobatics: m.acrobatics.map(Modifier.init(modifier:)),
            .animalHandling: m.animalHandling.map(Modifier.init(modifier:)),
            .arcana: m.arcana.map(Modifier.init(modifier:)),
            .athletics: m.athletics.map(Modifier.init(modifier:)),
            .deception: m.deception.map(Modifier.init(modifier:)),
            .history: m.history.map(Modifier.init(modifier:)),
            .insight: m.insight.map(Modifier.init(modifier:)),
            .intimidation: m.intimidation.map(Modifier.init(modifier:)),
            .investigation: m.investigation.map(Modifier.init(modifier:)),
            .medicine: m.medicine.map(Modifier.init(modifier:)),
            .nature: m.nature.map(Modifier.init(modifier:)),
            .perception: m.perception.map(Modifier.init(modifier:)),
            .performance: m.performance.map(Modifier.init(modifier:)),
            .persuasion: m.persuasion.map(Modifier.init(modifier:)),
            .religion: m.religion.map(Modifier.init(modifier:)),
            .sleightOfHand: m.sleightOfHand.map(Modifier.init(modifier:)),
            .stealth: m.stealth.map(Modifier.init(modifier:)),
            .survival: m.survival.map(Modifier.init(modifier:))
        ]

        self.init(
            name: m.name,
            size: CreatureSize(englishName: m.size),
            type: m.type,
            subtype: m.subtype.nonEmptyString,
            alignment: Alignment(englishName: m.alignment),

            armorClass: m.armorClass,
            armor: (m.armorDesc?.nonEmptyString).map { [Armor(name: $0, armorClass: m.armorClass)] } ?? [],
            hitPointDice: hitPointDice,
            hitPoints: m.hitPoints,
            movement: (m.speedJSON ?? m.speed.rightValue).map { speeds in
                [
                    MovementMode.walk: speeds.walk,
                    MovementMode.fly: speeds.fly,
                    MovementMode.swim: speeds.swim,
                    MovementMode.climb: speeds.climb,
                ].compactMapValues { $0 }
            },

            abilityScores: AbilityScores(open5eMonster: m),

            savingThrows: [
                .strength: m.strengthSave.map(Modifier.init(modifier:)),
                .dexterity: m.dexteritySave.map(Modifier.init(modifier:)),
                .constitution: m.constitutionSave.map(Modifier.init(modifier:)),
                .intelligence: m.intelligenceSave.map(Modifier.init(modifier:)),
                .wisdom: m.wisdomSave.map(Modifier.init(modifier:)),
                .charisma: m.charismaSave.map(Modifier.init(modifier:)),
            ].compactMapValues { $0 },

            skills: optionalSkills.compactMapValues { $0 },
            initiative: nil,

            damageVulnerabilities: m.damageVulnerabilities.nonEmptyString,
            damageResistances: m.damageResistances.nonEmptyString,
            damageImmunities: m.damageImmunities.nonEmptyString,
            conditionImmunities: m.conditionImmunities.nonEmptyString,

            senses: m.senses.nonEmptyString,
            languages: m.languages.nonEmptyString,

            challengeRating: Fraction(rawValue: m.challengeRating),

            features: m.specialAbilities?.leftValue?.map { a in
                CreatureFeature(id: generateUUID(), name: a.name, description: a.desc)
            } ?? [],
            actions: m.actions?.leftValue?.map { a in
                CreatureAction(id: generateUUID(), name: a.name, description: a.desc)
            } ?? [],
            reactions: m.reactions?.leftValue?.map { r in
                CreatureAction(id: generateUUID(), name: r.name, description: r.desc)
            } ?? [],
            legendary: m.legendaryActions?.leftValue.map { actions in
                Legendary(
                    description: m.legendaryDesc,
                    actions: actions.map { a in
                        ParseableCreatureAction(input: CreatureAction(id: generateUUID(), name: a.name, description: a.desc))
                    }
                )
            }
        )
    }
}

private extension AbilityScores {
    init(open5eMonster m: O5e.Monster) {
        self.init(
            strength: AbilityScore(m.strength),
            dexterity: AbilityScore(m.dexterity),
            constitution: AbilityScore(m.constitution),
            intelligence: AbilityScore(m.intelligence),
            wisdom: AbilityScore(m.wisdom),
            charisma: AbilityScore(m.charisma)
        )
    }
}

private extension Spell {
    init?(open5eSpell s: O5e.Spell, realm: CompendiumItemKey.Realm) {
        self.init(
            realm: realm,
            name: s.name,
            level: s.levelInt == 0 ? nil : s.levelInt,
            castingTime: s.castingTime,
            range: s.range,
            components: s.components.components(separatedBy: ",").compactMap {
                switch $0.trimmingCharacters(in: CharacterSet.whitespaces) {
                case "V": return .verbal
                case "S": return .somatic
                case "M": return .material
                default: return nil
                }
            },
            ritual: s.ritual == "yes",
            duration: s.duration,
            school: s.school,
            concentration: s.concentration == "yes",
            description: ParseableSpellDescription(input: s.desc),
            higherLevelDescription: s.higherLevel,
            classes: s.spellClass.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) },
            material: s.material
        )
    }
}

public extension CompendiumDataSource {

    func toOpen5eAPIResults() -> some CompendiumDataSource<[Open5eAPIResult]> where Output == [O5e.Monster] {
        MapCompendiumDataSource(source: self) { monsters in monsters.map { .left($0) } }
    }

    func toOpen5eAPIResults() -> some CompendiumDataSource<[Open5eAPIResult]> where Output == [O5e.Spell] {
        MapCompendiumDataSource(source: self) { spells in spells.map { .right($0) } }
    }

}
