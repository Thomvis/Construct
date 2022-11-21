//
//  Open5eMonsterDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels
import Helpers
import Dice
import AsyncAlgorithms

public class Open5eMonsterDataSourceReader: CompendiumDataSourceReader {
    public static let name = "Open5eMonsterDataSourceReader"

    public let dataSource: CompendiumDataSource

    public init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    public func makeJob() -> CompendiumDataSourceReaderJob {
        return Job(source: dataSource)
    }

    struct Job: CompendiumDataSourceReaderJob {
        let source: CompendiumDataSource

        var output: AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
            get async throws {
                let data = try await source.read()

                let monsters: [O5e.Monster]
                do {
                    monsters = try JSONDecoder().decode([O5e.Monster].self, from: data)
                } catch {
                    throw CompendiumDataSourceReaderError.incompatibleDataSource
                }

                return monsters.async.map { m in
                    guard let monster = Monster(open5eMonster: m, realm: .core) else { return .invalidItem(String(describing: m)) }
                    return .item(monster)
                }.stream
            }
        }
    }
    
}

private extension Monster {
    init?(open5eMonster m: O5e.Monster, realm: CompendiumItemKey.Realm) {
        self.init(realm: realm, stats: StatBlock(open5eMonster: m)!, challengeRating: Fraction(rawValue: m.challengeRating)!)
    }
}

private extension StatBlock {
    init?(open5eMonster m: O5e.Monster) {
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
            size: CreatureSize(englishName: m.size.rawValue)!,
            type: m.type.rawValue,
            subtype: m.subtype.nonEmptyString,
            alignment: Alignment(englishName: m.alignment.rawValue),

            armorClass: m.armorClass,
            armor: (m.armorDesc?.nonEmptyString).map { [Armor(name: $0, armorClass: m.armorClass)] } ?? [],
            hitPointDice: hitPointDice,
            hitPoints: m.hitPoints,
            movement: [
                .walk: m.speedJSON.walk,
                .fly: m.speedJSON.fly,
                .swim: m.speedJSON.swim,
                .climb: m.speedJSON.climb
            ].compactMapValues { $0 },

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

            challengeRating: Fraction(rawValue: m.challengeRating)!,

            features: m.specialAbilities?.map { a in
                CreatureFeature(name: a.name, description: a.desc)
            } ?? [],
            actions: m.actions?.map { a in
                CreatureAction(name: a.name, description: a.desc)
            } ?? [],
            reactions: m.reactions?.map { r in
                CreatureAction(name: r.name, description: r.desc)
            } ?? [],
            legendary: m.legendaryActions.map { actions in
                Legendary(
                    description: m.legendaryDesc,
                    actions: actions.map { a in
                        ParseableCreatureAction(input: CreatureAction(name: a.name, description: a.desc))
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
