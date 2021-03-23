//
//  Open5eMonsterDataSourceReader.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

class Open5eMonsterDataSourceReader: CompendiumDataSourceReader {
    static let name = "Open5eMonsterDataSourceReader"

    let dataSource: CompendiumDataSource

    init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    func read() -> CompendiumDataSourceReaderJob {
        return Job(data: dataSource.read())
    }

    class Job: CompendiumDataSourceReaderJob {
        let progress = Progress(totalUnitCount: 0)
        let items: AnyPublisher<CompendiumItem, Error>

        init(data: AnyPublisher<Data, Error>) {
            items = data.flatMap { data -> AnyPublisher<CompendiumItem, Error> in
                do {
                    let monsters = try JSONDecoder().decode([O5e.Monster].self, from: data)
                    return Publishers.Sequence(sequence: monsters.compactMap { m in
                        Monster(open5eMonster: m, realm: .core)
                    }).eraseToAnyPublisher()
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
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
            .acrobatics: m.acrobatics.map(Modifier.init),
            .animalHandling: m.animalHandling.map(Modifier.init),
            .arcana: m.arcana.map(Modifier.init),
            .athletics: m.athletics.map(Modifier.init),
            .deception: m.deception.map(Modifier.init),
            .history: m.history.map(Modifier.init),
            .insight: m.insight.map(Modifier.init),
            .intimidation: m.intimidation.map(Modifier.init),
            .investigation: m.investigation.map(Modifier.init),
            .medicine: m.medicine.map(Modifier.init),
            .nature: m.nature.map(Modifier.init),
            .perception: m.perception.map(Modifier.init),
            .performance: m.performance.map(Modifier.init),
            .persuasion: m.persuasion.map(Modifier.init),
            .religion: m.religion.map(Modifier.init),
            .sleightOfHand: m.sleightOfHand.map(Modifier.init),
            .stealth: m.stealth.map(Modifier.init),
            .survival: m.survival.map(Modifier.init)
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
                .strength: m.strengthSave.map(Modifier.init),
                .dexterity: m.dexteritySave.map(Modifier.init),
                .constitution: m.constitutionSave.map(Modifier.init),
                .intelligence: m.intelligenceSave.map(Modifier.init),
                .wisdom: m.wisdomSave.map(Modifier.init),
                .charisma: m.charismaSave.map(Modifier.init),
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
            } ?? []
        )
    }
}

private extension AbilityScores {
    init(open5eMonster m: O5e.Monster) {
        self.strength = AbilityScore(m.strength)
        self.dexterity = AbilityScore(m.dexterity)
        self.constitution = AbilityScore(m.constitution)
        self.intelligence = AbilityScore(m.intelligence)
        self.wisdom = AbilityScore(m.wisdom)
        self.charisma = AbilityScore(m.charisma)
    }
}
