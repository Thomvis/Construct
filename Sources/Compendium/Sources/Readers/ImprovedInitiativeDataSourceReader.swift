//
//  ImprovedInitiativeDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels
import Helpers
import Dice

public class ImprovedInitiativeDataSourceReader: CompendiumDataSourceReader {
    public static let name = "ImprovedInitiativeDataSourceReader"

    public var dataSource: any CompendiumDataSource<Data>
    let generateUUID: () -> UUID

    public init(dataSource: any CompendiumDataSource<Data>, generateUUID: @escaping () -> UUID) {
        self.dataSource = dataSource
        self.generateUUID = generateUUID
    }

    public func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        try dataSource.read().flatMap { data in
            let file: [String:String]
            do {
                file = try JSONDecoder().decode([String: String].self, from: data)
            } catch {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }

            guard let creatureListJson = file["ImprovedInitiative.Creatures"] else {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }

            let creatureList = try JSONDecoder().decode([String].self, from: creatureListJson.data(using: .utf8)!)

            return creatureList
                .lazy
                .compactMap { file["ImprovedInitiative.Creatures.\($0)"]?.data(using:. utf8) }
                .compactMap { try? JSONDecoder().decode(ImprovedInitiative.Creature.self, from: $0) }
                .map { creature -> CompendiumDataSourceReaderOutput in
                    guard let monster = Monster(improvedInitiativeCreature: creature, realm: .init(realmId), generateUUID: self.generateUUID) else {
                        return .invalidItem(String(describing: creature))
                    }
                    return .item(monster)
                }
                .async
        }.stream
    }

}

extension Monster {
    init?(
        improvedInitiativeCreature c: ImprovedInitiative.Creature,
        realm: CompendiumItemKey.Realm,
        generateUUID: () -> UUID
    ) {
        guard let stats = StatBlock(improvedInitiativeCreature: c, generateUUID: generateUUID),
                let cr = Fraction(rawValue: c.Challenge)
        else { return nil }

        self.init(realm: realm, stats: stats, challengeRating: cr)
    }
}

extension StatBlock {
    init?(improvedInitiativeCreature c: ImprovedInitiative.Creature, generateUUID: () -> UUID) {
        let abilities = AbilityScores(improvedInitiativeCreature: c.Abilities)
        
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
                CreatureFeature(id: generateUUID(), name: t.Name, description: t.Content)
            },
            actions: c.Actions.map { a in
                CreatureAction(id: generateUUID(), name: a.Name, description: a.Content)
            },
            reactions: c.Reactions.map { r in
                CreatureAction(id: generateUUID(), name: r.Name, description: r.Content)
            },
            legendary: with(c.LegendaryActions) { actions in
                let isDescriptionAction: (ImprovedInitiative.Creature.TraitOrAction) -> Bool = { $0.Name == "" || $0.Name == "Legendary Actions" }

                let description = actions.filter(isDescriptionAction).first?.Content

                return Legendary(
                    description: description,
                    actions: actions.filter { !isDescriptionAction($0) }.map { a in
                        ParseableCreatureAction(input: CreatureAction(id: generateUUID(), name: a.Name, description: a.Content))
                    }
                )
            }
        )
    }
}

extension AbilityScores {
    init(improvedInitiativeCreature c: ImprovedInitiative.Creature.Abilities) {
        self.init(
            strength: AbilityScore(c.Str),
            dexterity: AbilityScore(c.Dex),
            constitution: AbilityScore(c.Con),
            intelligence: AbilityScore(c.Int),
            wisdom: AbilityScore(c.Wis),
            charisma: AbilityScore(c.Cha)
        )
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
