//
//  ImprovedInitiativeDataSourceReader.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

class ImprovedInitiativeDataSourceReader: CompendiumDataSourceReader {
    static let name = "ImprovedInitiativeDataSourceReader"

    var dataSource: CompendiumDataSource

    init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    func read() -> CompendiumDataSourceReaderJob {
        return Job(data: dataSource.read())
    }

    class Job: CompendiumDataSourceReaderJob {
        let output: AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError>

        init(data: AnyPublisher<Data, CompendiumDataSourceError>) {
            output = data
                .mapError { CompendiumDataSourceReaderError.dataSource($0) }
                .flatMap { data -> AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError> in
                    do {
                        let file = try JSONDecoder().decode([String: String].self, from: data)
                        guard let creatureListJson = file["ImprovedInitiative.Creatures"] else {
                            return Fail(error: .incompatibleDataSource).eraseToAnyPublisher()
                        }

                        let creatureList = try JSONDecoder().decode([String].self, from: creatureListJson.data(using: .utf8)!)
                        let monsters = try creatureList
                            .compactMap { file["ImprovedInitiative.Creatures.\($0)"]?.data(using:. utf8) }
                            .map { try JSONDecoder().decode(ImprovedInitiative.Creature.self, from: $0) }
                            .map { creature -> CompendiumDataSourceReaderOutput in
                                guard let monster = Monster(improvedInitiativeCreature: creature, realm: .core) else {
                                    return .invalidItem(String(describing: creature))
                                }
                                return .item(monster)
                            }

                        return Publishers.Sequence(sequence: monsters).eraseToAnyPublisher()
                    } catch {
                        return Fail(error: .incompatibleDataSource).eraseToAnyPublisher()
                    }
                }.eraseToAnyPublisher()
        }
    }
}

extension Monster {
    init?(improvedInitiativeCreature c: ImprovedInitiative.Creature, realm: CompendiumItemKey.Realm) {
        guard let stats = StatBlock(improvedInitiativeCreature: c), let cr = Fraction(rawValue: c.Challenge) else { return nil }
        self.init(realm: realm, stats: stats, challengeRating: cr)
    }
}

extension StatBlock {
    init?(improvedInitiativeCreature c: ImprovedInitiative.Creature) {
        guard let abilities = AbilityScores(improvedInitiativeCreature: c.Abilities) else {
            return nil
        }

        let parsedType = DataSourceReaderParsers.typeParser.run(c.Type)
        if parsedType == nil || parsedType?.0 == nil || parsedType?.3 == nil {
            print("Could not parse type: \(c.Type)")
        }

        self.init(
            name: c.Name,
            size: parsedType?.0,
            type: parsedType?.1.nonEmptyString,
            subtype: parsedType?.2?.nonEmptyString,
            alignment: parsedType?.3,

            armorClass: c.AC.Value,
            armor: (DataSourceReaderParsers.parenthesizedStringParser.run(c.AC.Notes)).map { [Armor(name: $0, armorClass: c.AC.Value)] } ?? [],
            hitPointDice: (DataSourceReaderParsers.parenthesizedStringParser.run(c.HP.Notes)).flatMap { DiceExpressionParser.parse($0) } ?? .number(0),
            hitPoints: c.HP.Value,
            movement: c.Speed
                .compactMap { s in DataSourceReaderParsers.movementTupleParser.run(s) }
                .flatMap { $0 }
                .nonEmptyArray
                .map { Dictionary($0) { lhs, rhs in lhs } },

            abilityScores: abilities,

            savingThrows: Dictionary(uniqueKeysWithValues: c.Saves.compactMap { skill in
                guard let s = Ability(abbreviation: skill.Name), let m = skill.Modifier else { return nil }
                return (s, Modifier(modifier: m))
            }),
            skills: Dictionary(uniqueKeysWithValues: c.Skills.compactMap { skill in
                // Fixme: better parsing of skill name
                guard let s = Skill(rawValue: skill.Name.lowercased()), let m = skill.Modifier else { return nil }
                return (s, Modifier(modifier: m))
            }),
            initiative: nil,

            damageVulnerabilities: c.DamageVulnerabilities.joined(separator: ", ").nonEmptyString,
            damageResistances: c.DamageResistances.joined(separator: ", ").nonEmptyString,
            damageImmunities: c.DamageImmunities.joined(separator: ", ").nonEmptyString,
            conditionImmunities: c.ConditionImmunities.joined(separator: ", ").nonEmptyString,

            senses: c.Senses.joined(separator: ", ").nonEmptyString,
            languages: c.Languages.joined(separator: ", ").nonEmptyString,

            challengeRating: Fraction(rawValue: c.Challenge)!,

            features: c.Traits.map { t in
                CreatureFeature(name: t.Name, description: t.Content)
            },
            actions: c.Actions.map { a in
                CreatureAction(name: a.Name, description: a.Content)
            },
            reactions: c.Reactions.map { r in
                CreatureAction(name: r.Name, description: r.Content)
            },
            legendary: with(c.LegendaryActions) { actions in
                let isDescriptionAction: (ImprovedInitiative.Creature.TraitOrAction) -> Bool = { $0.Name == "" || $0.Name == "Legendary Actions" }

                let description = actions.filter(isDescriptionAction).first?.Content

                return Legendary(
                    description: description,
                    actions: actions.filter { !isDescriptionAction($0) }.map { a in
                        CreatureAction(name: a.Name, description: a.Content)
                    }
                )
            }
        )
    }
}

extension AbilityScores {
    init?(improvedInitiativeCreature c: ImprovedInitiative.Creature.Abilities) {
        self.strength = AbilityScore(c.Str)
        self.dexterity = AbilityScore(c.Dex)
        self.constitution = AbilityScore(c.Con)
        self.intelligence = AbilityScore(c.Int)
        self.wisdom = AbilityScore(c.Wis)
        self.charisma = AbilityScore(c.Cha)
    }
}

extension Array where Element == TypeComponent {
    var size: CreatureSize? {
        for c in self {
            if case .size(let s) = c {
                return s
            }
        }
        return nil
    }

    var type: String? {
        for c in self {
            if case .type(let t) = c {
                return t
            }
        }
        return nil
    }

    var subtype: String? {
        for c in self {
            if case .subtype(let t) = c {
                return t
            }
        }
        return nil
    }

    var alignment: Alignment? {
        for c in self {
            if case .alignment(let a) = c {
                return a
            }
        }
        return nil
    }
}
