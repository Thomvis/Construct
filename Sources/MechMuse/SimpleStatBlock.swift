import Foundation
import GameModels
import Helpers
import JSONSchemaBuilder

@Schemable
public struct SimpleStatBlock: Codable, Equatable, Hashable {
    public var name: String
    public var size: String?
    @SchemaOptions(.comment("The creature type (e.g. beast, celestial, undead, etc.)"))
    public var type: String?
    public var subtype: String?
    public var alignment: String?

    public var armorClass: Int?
    public var hitPoints: Int?

    // Speeds broken out as simple optional fields for reliable structured output
    public var walkSpeed: Int?
    public var flySpeed: Int?
    public var swimSpeed: Int?
    public var climbSpeed: Int?
    public var burrowSpeed: Int?

    public var abilities: Abilities?
    @SchemaOptions(.comment("Keys are the ability names (e.g. strength)"))
    public var saves: [String: Int]?
    @SchemaOptions(.comment("Keys are the skill names (e.g. perception)"))
    public var skills: [String: Int]?

    public var damageVulnerabilities: String?
    public var damageResistances: String?
    public var damageImmunities: String?
    public var conditionImmunities: String?

    public var senses: String?
    public var languages: String?

    public var challengeRating: String?
    public var level: Int?

    public var features: [NamedTextItem]?
    public var actions: [NamedTextItem]?
    public var reactions: [NamedTextItem]?

    public var legendaryDescription: String?
    public var legendaryActions: [NamedTextItem]?

    @Schemable
    public struct Abilities: Codable, Equatable, Hashable {
        public var strength: Int?
        public var dexterity: Int?
        public var constitution: Int?
        public var intelligence: Int?
        public var wisdom: Int?
        public var charisma: Int?

        public init(
            strength: Int? = nil,
            dexterity: Int? = nil,
            constitution: Int? = nil,
            intelligence: Int? = nil,
            wisdom: Int? = nil,
            charisma: Int? = nil
        ) {
            self.strength = strength
            self.dexterity = dexterity
            self.constitution = constitution
            self.intelligence = intelligence
            self.wisdom = wisdom
            self.charisma = charisma
        }
    }

    @Schemable
    public struct NamedTextItem: Codable, Equatable, Hashable {
        public var name: String
        public var description: String

        public init(name: String, description: String) {
            self.name = name
            self.description = description
        }
    }
}

public extension SimpleStatBlock {
    init(statBlock: StatBlock) {
        self.name = statBlock.name
        self.size = statBlock.size?.rawValue
        self.type = statBlock.type?.result?.value?.rawValue ?? statBlock.type?.input
        self.subtype = statBlock.subtype
        self.alignment = statBlock.alignment?.localizedDisplayName
        self.armorClass = statBlock.armorClass
        self.hitPoints = statBlock.hitPoints
        self.walkSpeed = statBlock.movement?[.walk]
        self.flySpeed = statBlock.movement?[.fly]
        self.swimSpeed = statBlock.movement?[.swim]
        self.climbSpeed = statBlock.movement?[.climb]
        self.burrowSpeed = statBlock.movement?[.burrow]

        if let a = statBlock.abilityScores {
            self.abilities = .init(
                strength: a.score(for: .strength).score,
                dexterity: a.score(for: .dexterity).score,
                constitution: a.score(for: .constitution).score,
                intelligence: a.score(for: .intelligence).score,
                wisdom: a.score(for: .wisdom).score,
                charisma: a.score(for: .charisma).score
            )
        } else {
            self.abilities = nil
        }

        self.damageVulnerabilities = statBlock.damageVulnerabilities
        self.damageResistances = statBlock.damageResistances
        self.damageImmunities = statBlock.damageImmunities
        self.conditionImmunities = statBlock.conditionImmunities

        self.senses = statBlock.senses
        self.languages = statBlock.languages
        self.challengeRating = statBlock.challengeRating?.rawValue
        self.level = statBlock.level

        self.features = statBlock.features.map { .init(name: $0.input.name, description: $0.input.description) }
        self.actions = statBlock.actions.map { .init(name: $0.input.name, description: $0.input.description) }
        self.reactions = statBlock.reactions.map { .init(name: $0.input.name, description: $0.input.description) }

        self.legendaryDescription = statBlock.legendary?.description
        self.legendaryActions = statBlock.legendary?.actions.map { .init(name: $0.input.name, description: $0.input.description) }
    }

    func toStatBlock() -> StatBlock {
        var result = StatBlock(
            name: name,
            size: size.flatMap { CreatureSize(rawValue: $0.lowercased()) },
            type: type,
            subtype: subtype,
            alignment: alignment.flatMap(Alignment.init(englishName:)),
            armorClass: armorClass,
            armor: [],
            hitPointDice: nil,
            hitPoints: hitPoints,
            movement: nil,
            abilityScores: nil,
            savingThrows: saves.map { saves in
                Dictionary(uniqueKeysWithValues: saves.compactMap { ability, modifier in
                    Ability(rawValue: ability.lowercased()).map {
                        ($0, Modifier(modifier: modifier))
                    }
                })
            } ?? [:],
            skills: skills.map { skills in
                Dictionary(uniqueKeysWithValues: skills.compactMap { skill, modifier in
                    Skill(rawValue: skill.lowercased()).map {
                        ($0, Modifier(modifier: modifier))
                    }
                })
            } ?? [:],
            initiative: nil,
            damageVulnerabilities: damageVulnerabilities,
            damageResistances: damageResistances,
            damageImmunities: damageImmunities,
            conditionImmunities: conditionImmunities,
            senses: senses,
            languages: languages,
            challengeRating: challengeRating.flatMap(Fraction.init(rawValue:)),
            features: (features ?? []).map { CreatureFeature(id: UUID(), name: $0.name, description: $0.description) },
            actions: (actions ?? []).map { CreatureAction(id: UUID(), name: $0.name, description: $0.description) },
            reactions: (reactions ?? []).map { CreatureAction(id: UUID(), name: $0.name, description: $0.description) },
            legendary: nil
        )

        if let abilities {
            result.abilityScores = AbilityScores(
                strength: AbilityScore(abilities.strength ?? 10),
                dexterity: AbilityScore(abilities.dexterity ?? 10),
                constitution: AbilityScore(abilities.constitution ?? 10),
                intelligence: AbilityScore(abilities.intelligence ?? 10),
                wisdom: AbilityScore(abilities.wisdom ?? 10),
                charisma: AbilityScore(abilities.charisma ?? 10)
            )
        }

        var movement: [MovementMode: Int] = [:]
        if let walkSpeed, walkSpeed > 0 { movement[.walk] = walkSpeed }
        if let flySpeed, flySpeed > 0 { movement[.fly] = flySpeed }
        if let swimSpeed, swimSpeed > 0 { movement[.swim] = swimSpeed }
        if let climbSpeed, climbSpeed > 0 { movement[.climb] = climbSpeed }
        if let burrowSpeed, burrowSpeed > 0 { movement[.burrow] = burrowSpeed }
        result.movement = movement.isEmpty ? nil : movement

        if let legendaryDescription = legendaryDescription, let legendaryActions = legendaryActions, !legendaryActions.isEmpty {
            result.legendary = StatBlock.Legendary(
                description: legendaryDescription.nonEmptyString,
                actions: legendaryActions.map { ParseableCreatureAction(input: CreatureAction(id: UUID(), name: $0.name, description: $0.description)) }
            )
        } else if let legendaryActions = legendaryActions, !legendaryActions.isEmpty {
            result.legendary = StatBlock.Legendary(description: nil, actions: legendaryActions.map { ParseableCreatureAction(input: CreatureAction(id: UUID(), name: $0.name, description: $0.description)) })
        }

        return result
    }
}


