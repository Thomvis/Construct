//
//  Creatures.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Dice
import Helpers

extension Optional: MigrationTarget where Wrapped == Alignment {
    public init(migrateFrom source: LegacyModels.Alignment?) {
        guard let source = source else {
            self = .unaligned
            return
        }

        switch (source.moral, source.ethic, source.inverse) {
        case (nil, nil, _): self = .any
        case (let moral?, nil, false): self = .moral(moral)
        case (let moral?, nil, true): self = .inverse(.moral(moral))
        case (nil, let ethic?, false): self = .ethic(ethic)
        case (nil, let ethic?, true): self = .inverse(.ethic(ethic))
        case (let moral?, let ethic?, false): self = .both(moral, ethic)
        case (let moral?, let ethic?, true): self = .inverse(.both(moral, ethic))
        }
    }
}

// Shared between monsters and characters
public struct StatBlock: Codable, Hashable {
    public var name: String
    public var size: CreatureSize?
    public var type: String?
    public var subtype: String?
    @Migrated public var alignment: Alignment?

    public var armorClass: Int?
    public var armor: [Armor]
    public var hitPointDice: DiceExpression?
    public var hitPoints: Int?
    public var movement: [MovementMode: Int]?

    public var abilityScores: AbilityScores?
    public var savingThrows: [Ability: Modifier]
    public var skills: [Skill: Modifier]
    public var initiative: Initiative?

    public var damageVulnerabilities: String?
    public var damageResistances: String?
    public var damageImmunities: String?
    public var conditionImmunities: String?

    public var senses: String?
    public var languages: String?

    public var challengeRating: Fraction?

    public var features: [ParseableCreatureFeature] // features & traits
    public var actions: [ParseableCreatureAction]
    @DecodableDefault.EmptyList public var reactions: [ParseableCreatureAction]
    public var legendary: Legendary?

    public init(name: String, size: CreatureSize? = nil, type: String? = nil, subtype: String? = nil, alignment: Alignment? = nil, armorClass: Int? = nil, armor: [Armor], hitPointDice: DiceExpression? = nil, hitPoints: Int? = nil, movement: [MovementMode : Int]? = nil, abilityScores: AbilityScores? = nil, savingThrows: [Ability : Modifier], skills: [Skill : Modifier], initiative: Initiative? = nil, damageVulnerabilities: String? = nil, damageResistances: String? = nil, damageImmunities: String? = nil, conditionImmunities: String? = nil, senses: String? = nil, languages: String? = nil, challengeRating: Fraction? = nil, features: [CreatureFeature], actions: [CreatureAction], reactions: [CreatureAction], legendary: Legendary? = nil) {
        self.name = name
        self.size = size
        self.type = type
        self.subtype = subtype
        self._alignment = Migrated(alignment)
        self.armorClass = armorClass
        self.armor = armor
        self.hitPointDice = hitPointDice
        self.hitPoints = hitPoints
        self.movement = movement
        self.abilityScores = abilityScores
        self.savingThrows = savingThrows
        self.skills = skills
        self.initiative = initiative
        self.damageVulnerabilities = damageVulnerabilities
        self.damageResistances = damageResistances
        self.damageImmunities = damageImmunities
        self.conditionImmunities = conditionImmunities
        self.senses = senses
        self.languages = languages
        self.challengeRating = challengeRating
        self.features = features.map(ParseableCreatureFeature.init)
        self.actions = actions.map(ParseableCreatureAction.init)
        self.reactions = reactions.map(ParseableCreatureAction.init)
        self.legendary = legendary
    }

    public func savingThrowModifier(_ ability: Ability) -> Modifier? {
        savingThrows[ability] ?? abilityScores?.score(for: ability).modifier
    }

    public func skillModifier(_ skill: Skill) -> Modifier? {
        skills[skill] ?? abilityScores?.score(for: skill.ability).modifier
    }

    public struct Legendary: Codable, Hashable {
        public var description: String?
        public var actions: [ParseableCreatureAction]

        public init(description: String? = nil, actions: [ParseableCreatureAction]) {
            self.description = description
            self.actions = actions
        }
    }
}

public enum CreatureSize: String, Codable, CaseIterable {
    case tiny, small, medium, large, huge, gargantuan
}

public enum LegacyModels {
    public struct Alignment: Equatable, Codable {
        public let moral: GameModels.Alignment.Moral?
        public let ethic: GameModels.Alignment.Ethic?
        public let inverse: Bool // true for non-good, non-chaotic, etc
    }
}

public enum Alignment: Hashable {
    case unaligned
    case any
    case moral(Moral)
    case ethic(Ethic)
    case both(Moral, Ethic)
    indirect case inverse(Alignment)

    var moral: Moral? {
        switch self {
        case .unaligned, .any, .ethic: return nil
        case .moral(let m): return m
        case .both(let m, _): return m
        case .inverse(let a): return a.moral
        }
    }

    var ethic: Ethic? {
        switch self {
        case .unaligned, .any, .moral: return nil
        case .ethic(let e): return e
        case .both(_, let e): return e
        case .inverse(let a): return a.ethic
        }
    }

    var inverse: Bool {
        if case .inverse = self {
            return true
        }
        return false
    }

    public enum Moral: String, Codable {
        case lawful, neutral, chaotic
    }

    public enum Ethic: String, Codable {
        case good, neutral, evil
    }

    public static let lawfulGood: Self = .both(.lawful, .good)
    public static let neutralGood: Self = .both(.neutral, .good)
    public static let chaoticGood: Self = .both(.chaotic, .good)
    public static let lawfulNeutral: Self = .both(.lawful, .neutral)
    public static let neutral: Self = .both(.neutral, .neutral)
    public static let chaoticNeutral: Self = .both(.chaotic, .neutral)
    public static let lawfulEvil: Self = .both(.lawful, .evil)
    public static let neutralEvil: Self = .both(.neutral, .evil)
    public static let chaoticEvil: Self = .both(.chaotic, .evil)
}

public enum Ability: String, CaseIterable, Codable, Equatable {
    case strength, dexterity, constitution, intelligence, wisdom, charisma
}

public struct Armor: Codable, Hashable {
    public var name: String
    public var armorClass: ArmorClass
    public var requiredStrength: Int?
    public var imposesStealthDisadvantage: Bool

    public struct ArmorClass: Codable, Hashable {
        public let base: Int?
        public let addDex: Bool
        public let maxDex: Int?
        public let bonus: Int

        public init(_ base: Int, addDex: Bool, maxDex: Int?) {
            self.base = base
            self.addDex = addDex
            self.maxDex = maxDex
            self.bonus = 0
        }

        public init(_ bonus: Int) {
            self.base = nil
            self.addDex = false
            self.maxDex = nil
            self.bonus = bonus
        }
    }
}

public struct AbilityScore: Hashable, ExpressibleByIntegerLiteral, Codable {

    public var score: Int

    public init(_ value: Int) {
        self.score = value
    }

    public init(integerLiteral value: Int) {
        self.score = value
    }

    public var modifier: Modifier {
        return Modifier(modifier: Int(floor(Double(score - 10)/2.0)))
    }

    public static func +(lhs: AbilityScore, rhs: Int) -> AbilityScore {
        return AbilityScore(lhs.score + rhs)
    }

    public static func +=(lhs: inout AbilityScore, rhs: Int) {
        lhs.score += rhs
    }
}

public struct AbilityScores: Hashable, Codable {
    public var strength: AbilityScore
    public var dexterity: AbilityScore
    public var constitution: AbilityScore
    public var intelligence: AbilityScore
    public var wisdom: AbilityScore
    public var charisma: AbilityScore

    public init(strength: AbilityScore, dexterity: AbilityScore, constitution: AbilityScore, intelligence: AbilityScore, wisdom: AbilityScore, charisma: AbilityScore) {
        self.strength = strength
        self.dexterity = dexterity
        self.constitution = constitution
        self.intelligence = intelligence
        self.wisdom = wisdom
        self.charisma = charisma
    }

    public func score(for ability: Ability) -> AbilityScore {
        switch ability {
            case .strength: return strength
            case .dexterity: return dexterity
            case .constitution: return constitution
            case .intelligence: return intelligence
            case .wisdom: return wisdom
            case .charisma: return charisma
        }
    }

    public mutating func set(_ ability: Ability, to score: Int) {
        switch ability {
        case .strength: self.strength = AbilityScore(score)
        case .dexterity: self.dexterity = AbilityScore(score)
        case .constitution: self.constitution = AbilityScore(score)
        case .intelligence: self.intelligence = AbilityScore(score)
        case .wisdom: self.wisdom = AbilityScore(score)
        case .charisma: self.charisma = AbilityScore(score)
        }
    }

    public subscript(ability: Ability) -> AbilityScore {
        get {
            switch ability {
                case .strength: return strength
                case .dexterity: return dexterity
                case .constitution: return constitution
                case .intelligence: return intelligence
                case .wisdom: return wisdom
                case .charisma: return charisma
            }
        }
        set(score) {
            switch ability {
            case .strength: self.strength = score
            case .dexterity: self.dexterity = score
            case .constitution: self.constitution = score
            case .intelligence: self.intelligence = score
            case .wisdom: self.wisdom = score
            case .charisma: self.charisma = score
            }
        }
    }
}

public struct Modifier: Codable, Hashable {
    public var modifier: Int

    public init(modifier: Int) {
        self.modifier = modifier
    }

    public func apply(to expr: DiceExpression) -> DiceExpression {
        return expr + modifier
    }
}

public enum Skill: String, CaseIterable, Codable {
    case acrobatics, animalHandling, arcana, athletics,
        deception, history, insight, intimidation,
        investigation, medicine, nature, perception,
        performance, persuasion, religion, sleightOfHand,
        stealth, survival

    public var ability: Ability {
        switch self {
        case .athletics:
            return .strength
        case .acrobatics, .sleightOfHand, .stealth:
            return .dexterity
        case .arcana, .history, .investigation, .nature, .religion:
            return .intelligence
        case .animalHandling, .insight, .medicine, .perception, .survival:
            return .wisdom
        case .deception, .intimidation, .performance, .persuasion:
            return .charisma
        }
    }
}

public enum MovementMode: String, Codable, CaseIterable, Equatable {
    case walk
    case fly
    case swim
    case climb
    case burrow
}

public enum DamageType: String, Codable {
    case acid, bludgeoning, cold, fire, force, lightning, necrotic, piercing, poison, phsychic, radiant, slashing, thunder
}

public enum CreatureCondition: String, Codable {
    case blinded, charmed, deafened, fatigued, frightened, grappled, incapacitated, invisible, paralyzed, petrified, poisioned, prone, restrained, stunned, unconcious
}

public struct CreatureAction: Codable, Hashable {
    public var name: String
    public var description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

public struct CreatureFeature: Codable, Hashable {
    public var name: String
    public var description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

public extension CreatureSize {
    var localizedDisplayName: String {
        switch self {
        case .tiny: return NSLocalizedString("tiny", comment: "Creature size tiny")
        case .small: return NSLocalizedString("small", comment: "Creature size small")
        case .medium: return NSLocalizedString("medium", comment: "Creature size medium")
        case .large: return NSLocalizedString("large", comment: "Creature size large")
        case .huge: return NSLocalizedString("huge", comment: "Creature size huge")
        case .gargantuan: return NSLocalizedString("garganguan", comment: "Creature size gargantuan")
        }
    }
}

public extension Alignment.Ethic {
    var localizedDisplayName: String {
        switch self {
        case .good: return NSLocalizedString("good", comment: "Alignment ethic good")
        case .neutral: return NSLocalizedString("neutral", comment: "Alignment ethic neutral")
        case .evil: return NSLocalizedString("evil", comment: "Alignment ethic evil")
        }
    }
}

public extension Alignment.Moral {
    var localizedDisplayName: String {
        switch self {
        case .lawful: return NSLocalizedString("lawful", comment: "Alignment moral lawful")
        case .neutral: return NSLocalizedString("neutral", comment: "Alignment moral neutral")
        case .chaotic: return NSLocalizedString("chaotic", comment: "Alignment moral chaotic")
        }
    }
}

public extension Alignment {
    var localizedDisplayName: String {
        switch self {
        case .unaligned: return NSLocalizedString("unaligned", comment: "Unaligned")
        case .any: return NSLocalizedString("any alignment", comment: "Any alignment")
        case .moral(let m): return String(format: NSLocalizedString("any %@ alignment", comment: "Any moral alignment"), m.localizedDisplayName)
        case .ethic(let e): return String(format: NSLocalizedString("any %@ alignment", comment: "Any ethic alignment"), e.localizedDisplayName)
        case .both(let m, let e): return "\(m.localizedDisplayName) \(e.localizedDisplayName)"
        case .inverse(.moral(let m)): return String(format: NSLocalizedString("any non-%@ alignment", comment: "Any inverse moral alignment"), m.localizedDisplayName)
        case .inverse(.ethic(let e)): return String(format: NSLocalizedString("any non-%@ alignment", comment: "Any inverse ethic alignment"), e.localizedDisplayName)
        case .inverse(.both(let m, let e)): return String(format: NSLocalizedString("non-%@ non-%@", comment: "Inverse alignment (both)"), m.localizedDisplayName, e.localizedDisplayName)
        case .inverse(let a): return String(format: NSLocalizedString("non-%@", comment: "Inverse alignment (other)"), a.localizedDisplayName)
        }
    }
}

public extension MovementMode {
    var localizedDisplayName: String {
        switch self {
        case .walk: return NSLocalizedString("walk", comment: "Movement mode walking")
        case .fly: return NSLocalizedString("fly", comment: "Movement mode flying")
        case .swim: return NSLocalizedString("swim", comment: "Movement mode swimming")
        case .climb: return NSLocalizedString("climb", comment: "Movement mode climbing")
        case .burrow: return NSLocalizedString("burrow", comment: "Movement mode burrowing")
        }
    }
}

public extension Ability {
    var localizedAbbreviation: String {
        switch self {
        case .strength: return "str"
        case .dexterity: return "dex"
        case .constitution: return "con"
        case .intelligence: return "int"
        case .wisdom: return "wis"
        case .charisma: return "cha"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .strength: return NSLocalizedString("Strength", comment: "Ability Strength")
        case .dexterity: return NSLocalizedString("Dexterity", comment: "Ability Dexterity")
        case .constitution: return NSLocalizedString("Constitution", comment: "Ability Constitution")
        case .intelligence: return NSLocalizedString("Intelligence", comment: "Ability Intelligence")
        case .wisdom: return NSLocalizedString("Wisdom", comment: "Ability Wisdom")
        case .charisma: return NSLocalizedString("Charisma", comment: "Ability Charisma")
        }
    }

    init?(abbreviation: String) {
        guard let match = Self.allCases.first(where: { $0.localizedAbbreviation == abbreviation.lowercased() }) else { return nil }
        self = match
    }
}

extension Skill {
    public var localizedDisplayName: String {
        switch self {
            case .acrobatics: return NSLocalizedString("Acrobatics", comment: "Skill acrobatics")
            case .animalHandling: return NSLocalizedString("Animal Handling", comment: "Skill animalHandling")
            case .arcana: return NSLocalizedString("Arcana", comment: "Skill arcana")
            case .athletics: return NSLocalizedString("Athletics", comment: "Skill athletics")
            case .deception: return NSLocalizedString("Deception", comment: "Skill deception")
            case .history: return NSLocalizedString("History", comment: "Skill history")
            case .insight: return NSLocalizedString("Insight", comment: "Skill insight")
            case .intimidation: return NSLocalizedString("Intimidation", comment: "Skill intimidation")
            case .investigation: return NSLocalizedString("Investigation", comment: "Skill investigation")
            case .medicine: return NSLocalizedString("Medicine", comment: "Skill medicine")
            case .nature: return NSLocalizedString("Nature", comment: "Skill nature")
            case .perception: return NSLocalizedString("Perception", comment: "Skill perception")
            case .performance: return NSLocalizedString("Performance", comment: "Skill performance")
            case .persuasion: return NSLocalizedString("Persuasion", comment: "Skill persuasion")
            case .religion: return NSLocalizedString("Religion", comment: "Skill religion")
            case .sleightOfHand: return NSLocalizedString("Sleight Of Hand", comment: "Skill sleightOfHand")
            case .stealth: return NSLocalizedString("Stealth", comment: "Skill stealth")
            case .survival: return NSLocalizedString("Survival", comment: "Skill survival")
        }
    }
}

public extension Armor {
    static let padded = Armor(name: "Padded", armorClass: .init(11, addDex: true, maxDex: nil), requiredStrength: nil, imposesStealthDisadvantage: true)
    static let leather = Armor(name: "Leather", armorClass: .init(11, addDex: true, maxDex: nil), requiredStrength: nil, imposesStealthDisadvantage: false)
    static let studdedLeather = Armor(name: "Studded Leather", armorClass: .init(12, addDex: true, maxDex: nil), requiredStrength: nil, imposesStealthDisadvantage: false)
    static let hide = Armor(name: "Hide", armorClass: .init(12, addDex: true, maxDex: 2), requiredStrength: nil, imposesStealthDisadvantage: false)
    static let chainMail = Armor(name: "Chain Mail", armorClass: .init(16, addDex: false, maxDex: nil), requiredStrength: 13, imposesStealthDisadvantage: true)
    static let shield = Armor(name: "Shield", armorClass: .init(2), requiredStrength: nil, imposesStealthDisadvantage: false)

    static let allArmors: [Armor] = [.padded, .leather, .studdedLeather, .hide, .chainMail, .shield]

    static func armor(for name: String) -> Armor? {
        return allArmors.first { $0.name == name }
    }

    init(name: String, armorClass: Int) {
        self.name = name
        self.armorClass = .init(armorClass, addDex: false, maxDex: nil)
        self.requiredStrength = nil
        self.imposesStealthDisadvantage = false
    }

    func effectiveArmorClass(_ dexterity: AbilityScore) -> Int? {
        if let base = armorClass.base, armorClass.addDex, armorClass.maxDex == nil {
            return base + dexterity.modifier.modifier
        } else if let base = armorClass.base, armorClass.addDex, let maxDex = armorClass.maxDex {
            return base + min(maxDex, dexterity.modifier.modifier)
        } else if let base = armorClass.base, !armorClass.addDex {
            return base
        }

        return nil
    }
}

public struct Initiative: Codable, Hashable {
    public var modifier: Modifier
    public var advantage: Bool

    public init(modifier: Modifier, advantage: Bool) {
        self.modifier = modifier
        self.advantage = advantage
    }
}

extension Alignment: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let moral = try? container.decode(Moral.self, forKey: .moral)
        let ethic = try? container.decode(Ethic.self, forKey: .ethic)

        if (try? container.decode(Bool.self, forKey: .unaligned)) == true {
            self = .unaligned
        } else if (try? container.decode(Bool.self, forKey: .any)) == true {
            self = .any
        } else if let moral = moral, let ethic = ethic {
            self = .both(moral, ethic)
        } else if let moral = moral {
            self = .moral(moral)
        } else if let ethic = ethic {
            self = .ethic(ethic)
        } else if let inverse = try? container.decode(Alignment.self, forKey: .inverse) {
            self = .inverse(inverse)
        } else {
            throw CodableError.unrecognizedAlignment
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .unaligned:
            try container.encode(true, forKey: .unaligned)
        case .any:
            try container.encode(true, forKey: .any)
        case .moral(let m):
            try container.encode(m, forKey: .moral)
        case .ethic(let e):
            try container.encode(e, forKey: .ethic)
        case .both(let m, let e):
            try container.encode(m, forKey: .moral)
            try container.encode(e, forKey: .ethic)
        case .inverse(let a):
            try container.encode(a, forKey: .inverse)
        }
    }

    private enum CodingKeys: CodingKey {
        case unaligned
        case any
        case moral
        case ethic
        case inverse
    }

    enum CodableError: Error {
        case unrecognizedAlignment
    }
}

public extension StatBlock {
    static var `default`: StatBlock {
        StatBlock(name: "", size: nil, type: nil, subtype: nil, alignment: nil, armorClass: nil, armor: [], hitPointDice: nil, hitPoints: nil, movement: nil, abilityScores: nil, savingThrows: [:], skills: [:], damageVulnerabilities: nil, damageResistances: nil, damageImmunities: nil, conditionImmunities: nil, senses: nil, languages: nil, challengeRating: nil, features: [], actions: [], reactions: [])
    }
}
