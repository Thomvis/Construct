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
        let progress = Progress(totalUnitCount: 0)
        let items: AnyPublisher<CompendiumItem, Error>

        init(data: AnyPublisher<Data, Error>) {
            items = data.flatMap { data -> AnyPublisher<CompendiumItem, Error> in
                do {
                    let file = try JSONDecoder().decode([String: String].self, from: data)
                    guard let creatureListJson = file["ImprovedInitiative.Creatures"] else {
                        return Empty().eraseToAnyPublisher()
                    }

                    let creatureList = try JSONDecoder().decode([String].self, from: creatureListJson.data(using: .utf8)!)
                    let monsters = try creatureList
                        .compactMap { file["ImprovedInitiative.Creatures.\($0)"]?.data(using:. utf8) }
                        .map { try JSONDecoder().decode(ImprovedInitiative.Creature.self, from: $0) }
                        .compactMap { Monster(improvedInitiativeCreature: $0, realm: .core) }

                    return Publishers.Sequence(sequence: monsters).eraseToAnyPublisher()
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
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

        let parsedType = TypeComponent.parser.run(c.Type)
        if parsedType == nil {
            print("Could not parse type: \(c.Type)")
        }

        self.init(
            name: c.Name,
            size: parsedType?.0,
            type: parsedType?.1.nonEmptyString,
            subtype: parsedType?.2?.nonEmptyString,
            alignment: parsedType?.3,

            armorClass: c.AC.Value,
            armor: (parenthesizedStringParser.run(c.AC.Notes)).map { [Armor(name: $0, armorClass: c.AC.Value)] } ?? [],
            hitPointDice: (parenthesizedStringParser.run(c.HP.Notes)).flatMap { DiceExpressionParser.parse($0) } ?? .number(0),
            hitPoints: c.HP.Value,
            movement: [:], // fixme

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

private let parenthesizedStringParser: Parser<String> = char("(")
    .followed(by: any(character { $0 != ")" }).joined())
    .followed(by: char(")"))
    .map { $0.0.1 }

enum TypeComponent {
    case size(CreatureSize)
    case type(String)
    case subtype(String)
    case alignment(Alignment)

    // Parses strings like:
    // - Medium dragon, unaligned
    // - M humanoid (gnoll), chaotic neutral
    // - Large beast, monster manual, neutral
    static let parser: Parser<(CreatureSize, String, String?, Alignment)> = any(
        either(
            zip(
                either(
                    Self.sizeTypeParser.log("size"),
                    Self.alignmentParser.log("al")
                ),
                Self.endOfComponentParser.log("eoc")
            ).map { $0.0 },
            Self.skipComponentParser.log("skip")
        )
    ).map { $0.flatMap { $0} }.flatMap {
        guard let size = $0.size, let type = $0.type, let alignment = $0.alignment else { return nil }
        return (size, type, $0.subtype, alignment)
    }

    static let sizeTypeParser: Parser<[TypeComponent]> =
        word().flatMap { w in // type
            CreatureSize(englishName: w).map { TypeComponent.size($0) }
        }
        .followed(by: word().map { // type
            TypeComponent.type($0)
        })
        .followed(by: parenthesizedStringParser.map { // sub-type (optional)
            TypeComponent.subtype($0)
        }.optional()).map {
            [$0.0.0, $0.0.1, $0.1].compactMap { $0 }
        }

    static let alignmentParser = skip(until: Self.endOfComponentParser).flatMap { component in
        Alignment(englishName: component.0).map { [TypeComponent.alignment($0)] }
    }

    static let endOfComponentParser = char(",").followed(by: any(char(" "))).map { _ in () }.or(end())

    static let skipComponentParser: Parser<[TypeComponent]> = skip(until: Self.endOfComponentParser).flatMap {
        guard !$0.0.isEmpty else { return nil } // we must have skipped something
        return Array<TypeComponent>()
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
