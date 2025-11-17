//
//  StatBlock.swift
//  
//
//  Created by Thomas Visser on 05/11/2022.
//

import Foundation
import Helpers
import Dice
import Tagged
import ComposableArchitecture
import ComposableArchitecture

// Shared between monsters and characters
public struct StatBlock: Codable, Hashable {
    public var name: String
    public var size: CreatureSize?
    public var type: ParseableMonsterType?
    public var subtype: String?
    @Migrated public var alignment: Alignment?

    public var armorClass: Int?
    public var armor: [Armor]
    public var hitPointDice: DiceExpression?
    public var hitPoints: Int?
    public var movement: [MovementMode: Int]?

    public var abilityScores: AbilityScores?
    /// if the value is nil, the default proficiency bonus applies
    public var savingThrows: [Ability: Proficiency]
    /// if the value is nil, the default proficiency bonus applies
    public var skills: [Skill: Proficiency]
    public var initiative: Initiative?

    public var damageVulnerabilities: String?
    public var damageResistances: String?
    public var damageImmunities: String?
    public var conditionImmunities: String?

    public var senses: String?
    public var languages: String?

    public var challengeRating: Fraction?
    public var level: Int?

    public var features: IdentifiedArrayOf<ParseableCreatureFeature> // features & traits
    public var actions: IdentifiedArrayOf<ParseableCreatureAction>
    @DecodableDefault.EmptyList public var reactions: IdentifiedArrayOf<ParseableCreatureAction>
    public var legendary: Legendary?

    public init(name: String, size: CreatureSize? = nil, type: String? = nil, subtype: String? = nil, alignment: Alignment? = nil, armorClass: Int? = nil, armor: [Armor] = [], hitPointDice: DiceExpression? = nil, hitPoints: Int? = nil, movement: [MovementMode : Int]? = nil, abilityScores: AbilityScores? = nil, savingThrows: [Ability : Modifier] = [:], skills: [Skill : Modifier] = [:], initiative: Initiative? = nil, damageVulnerabilities: String? = nil, damageResistances: String? = nil, damageImmunities: String? = nil, conditionImmunities: String? = nil, senses: String? = nil, languages: String? = nil, challengeRating: Fraction? = nil, features: [CreatureFeature] = [], actions: [CreatureAction] = [], reactions: [CreatureAction] = [], legendary: Legendary? = nil) {
        self.name = name
        self.size = size
        self.type = type.map(ParseableMonsterType.init(input:))
        self.subtype = subtype
        self._alignment = Migrated(alignment)
        self.armorClass = armorClass
        self.armor = armor
        self.hitPointDice = hitPointDice
        self.hitPoints = hitPoints
        self.movement = movement
        self.abilityScores = abilityScores
        self.savingThrows = savingThrows.mapValues { .custom($0) }
        self.skills = skills.mapValues { .custom($0) }
        self.initiative = initiative
        self.damageVulnerabilities = damageVulnerabilities
        self.damageResistances = damageResistances
        self.damageImmunities = damageImmunities
        self.conditionImmunities = conditionImmunities
        self.senses = senses
        self.languages = languages
        self.challengeRating = challengeRating
        self.features = IdentifiedArrayOf(uniqueElements: features.map(ParseableCreatureFeature.init(input:)))
        self.actions = IdentifiedArrayOf(uniqueElements: actions.map(ParseableCreatureAction.init(input:)))
        self.reactions = IdentifiedArrayOf(uniqueElements: reactions.map(ParseableCreatureAction.init(input:)))
        self.legendary = legendary
    }

    public func savingThrowModifier(_ ability: Ability) -> Modifier {
        switch savingThrows[ability] {
        case .times(let t):
            return (abilityScores?.score(for: ability).modifier ?? 0) + t * proficiencyBonus
        case .custom(let m):
            return m
        case nil:
            return abilityScores?.score(for: ability).modifier ?? 0
        }
    }

    public func skillModifier(_ skill: Skill) -> Modifier {
        switch skills[skill] {
        case .times(let t):
            return (abilityScores?.score(for: skill.ability).modifier ?? 0) + t * proficiencyBonus
        case .custom(let m):
            return m
        case nil:
            return abilityScores?.score(for: skill.ability).modifier ?? 0
        }
    }

    public var proficiencyBonus: Modifier {
        assert(challengeRating == nil || level == nil)
        if let challengeRating {
            return crToProficiencyBonusMapping[challengeRating] ?? 0
        } else if let level {
            return levelToProficiencyBonusMapping[level] ?? 0
        }
        return 0
    }

    public var subheading: String {
        let type = [
            size?.localizedDisplayName.capitalized,
            self.type?.localizedDisplayName.nonEmptyString,
            (subtype?.capitalized.nonEmptyString).map { "(\($0))"}
        ].compactMap { $0 }.joined(separator: " ").nonEmptyString

        let alignment = self.alignment?.localizedDisplayName.capitalized
        return [type, alignment].compactMap { $0 }.joined(separator: ", ")
    }

    public struct Legendary: Codable, Hashable {
        public var description: String?
        public var actions: IdentifiedArrayOf<ParseableCreatureAction>

        public init(description: String? = nil, actions: [ParseableCreatureAction]) {
            self.description = description
            self.actions = IdentifiedArrayOf(uniqueElements: actions)
        }
    }

    public enum Proficiency: Hashable {
        case times(Int) // the bonus is equal to one or more times the proficiency bonus
        case custom(Modifier) // the bonus is equal to a custom modifier

        func modifier(proficiencyBonus: Modifier) -> Modifier {
            switch self {
            case .times(let t): return Modifier(modifier: t * proficiencyBonus.modifier)
            case .custom(let m): return m
            }
        }

        public var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }
    }
}

public enum NamedStatBlockContentItem: Equatable, Identifiable {
    case feature(ParseableCreatureFeature)
    case action(ParseableCreatureAction)
    case reaction(ParseableCreatureAction)
    case legendaryAction(ParseableCreatureAction)

    var input: NamedStatBlockContentItemInput {
        get {
            switch self {
            case .feature(let f): return f.input
            case .action(let a), .reaction(let a), .legendaryAction(let a): return a.input
            }
        }
        set {
            switch self {
            case .feature(var f):
                f.input = CreatureFeature(id: newValue.id, name: newValue.name, description: newValue.description)
                self = .feature(f)
            case .action(var a):
                a.input = CreatureAction(id: newValue.id, name: newValue.name, description: newValue.description)
                self = .action(a)
            case .reaction(var a):
                a.input = CreatureAction(id: newValue.id, name: newValue.name, description: newValue.description)
                self = .reaction(a)
            case .legendaryAction(var a):
                a.input = CreatureAction(id: newValue.id, name: newValue.name, description: newValue.description)
                self = .legendaryAction(a)
            }
        }
    }

    public var id: UUID {
        input.id
    }

    var concrete: NamedStatBlockContentItemParseable {
        switch self {
        case .feature(let f): return f
        case .action(let a), .reaction(let a), .legendaryAction(let a): return a
        }
    }

    public var type: NamedStatBlockContentItemType {
        switch self {
        case .feature: return .feature
        case .action: return .action
        case .reaction: return .reaction
        case .legendaryAction: return .legendaryAction
        }
    }

    public var parsed: NamedStatBlockContentItemParsed? {
        switch self {
        case .feature(let f): return f.result?.value
        case .action(let a): return a.result?.value
        case .reaction(let a): return a.result?.value
        case .legendaryAction(let a): return a.result?.value
        }
    }

    @discardableResult
    mutating public func parseIfNeeded() -> Bool {
        switch self {
        case .feature(var f):
            let res = f.parseIfNeeded()
            self = .feature(f)
            return res
        case .action(var a):
            let res = a.parseIfNeeded()
            self = .action(a)
            return res
        case .reaction(var a):
            let res = a.parseIfNeeded()
            self = .reaction(a)
            return res
        case .legendaryAction(var a):
            let res = a.parseIfNeeded()
            self = .legendaryAction(a)
            return res
        }
    }

}

public extension NamedStatBlockContentItem {

    var name: String {
        get { input.name }
        set { input.name = newValue }
    }

    var description: String {
        get { input.description }
        set { input.description = newValue }
    }

    var attributedName: AttributedString {
        concrete.attributedName
    }

    var attributedDescription: AttributedString {
        concrete.attributedDescription
    }
}

public protocol NamedStatBlockContentItemInput {
    var id: UUID { get }
    var name: String { get set }
    var description: String { get set }
}

public protocol NamedStatBlockContentItemParsed {
    var nameAnnotations: [Located<TextAnnotation>] { get }
    var descriptionAnnotations: [Located<TextAnnotation>] { get }
}

public protocol NamedStatBlockContentItemParseable {
    var name: String { get set }
    var description: String { get set }
    var attributedName: AttributedString { get }
    var attributedDescription: AttributedString { get }
}

extension Parseable: NamedStatBlockContentItemParseable where Input: NamedStatBlockContentItemInput, Result: NamedStatBlockContentItemParsed {

    public var name: String {
        get { input.name }
        set { input.name = newValue }
    }

    public var description: String {
        get { input.description }
        set { input.description = newValue }
    }

    public var attributedName: AttributedString {
        guard let parsed = result?.value else { return AttributedString(name) }

        var result = AttributedString(name)
        for annotation in parsed.nameAnnotations {
            result.apply(annotation)
        }
        return result
    }

    public var attributedDescription: AttributedString {
        guard let parsed = result?.value else { return AttributedString(description) }

        var result = AttributedString(description)
        for annotation in parsed.descriptionAnnotations {
            result.apply(annotation)
        }
        return result
    }
}

extension CreatureFeature: NamedStatBlockContentItemInput { }
extension CreatureAction: NamedStatBlockContentItemInput { }
extension ParsedCreatureFeature: NamedStatBlockContentItemParsed { }
extension ParsedCreatureAction: NamedStatBlockContentItemParsed { }

extension Parseable: Identifiable where Input: NamedStatBlockContentItemInput {
    public var id: UUID {
        input.id
    }
}

public enum NamedStatBlockContentItemType: Int, CaseIterable {
    case feature
    case action
    case reaction
    case legendaryAction

    public var localizedDisplayName: String {
        switch self {
        case .feature: return NSLocalizedString("feature", comment: "Named StatBlock Content Item Type: Feature")
        case .action: return NSLocalizedString("action", comment: "Named StatBlock Content Item Type: Action")
        case .reaction: return NSLocalizedString("reaction", comment: "Named StatBlock Content Item Type: Reaction")
        case .legendaryAction: return NSLocalizedString("legendary action", comment: "Named StatBlock Content Item Type: Legendary Action")
        }
    }
}

public extension StatBlock {
    subscript(itemsOfType type: NamedStatBlockContentItemType) -> IdentifiedArrayOf<NamedStatBlockContentItem> {
        get {
            switch type {
            case .feature: return features.map(NamedStatBlockContentItem.feature).identified
            case .action: return actions.map(NamedStatBlockContentItem.action).identified
            case .reaction: return reactions.map(NamedStatBlockContentItem.action).identified
            case .legendaryAction: return legendary?.actions.map(NamedStatBlockContentItem.action).identified ?? []
            }
        }
        set {
            switch (type, newValue.map(\.concrete) as Any) {
            case (.feature, let newFeatures as [ParseableCreatureFeature]): features = newFeatures.identified
            case (.action, let newActions as [ParseableCreatureAction]): actions = newActions.identified
            case (.reaction, let newActions as [ParseableCreatureAction]): reactions = newActions.identified
            case (.legendaryAction, let newActions as [ParseableCreatureAction]):
                if let newActions = newActions.nonEmptyArray {
                    if legendary != nil {
                        legendary?.actions = newActions.identified
                    } else {
                        legendary = Legendary(actions: newActions)
                    }
                } else {
                    legendary = nil
                }
            default:
                assertionFailure("Failed setting a StatBlock's itemsOfType due to a type mismatch")
            }
        }
    }
}

extension StatBlock.Proficiency: Codable {
    enum CodingKeys: CodingKey {
        case times
    }

    // backward compatible with an encoded Modifier
    public init(from decoder: Decoder) throws {

        if let container = try? decoder.container(keyedBy: CodingKeys.self),
            let times = try? container.decode(Int.self, forKey: .times)
        {
            self = .times(times)
        } else {
            self = .custom(try Modifier(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .times(let times):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(times, forKey: .times)
        case .custom(let m):
            try m.encode(to: encoder)
        }
    }
}

public extension StatBlock.Proficiency {
    init(modifier: Modifier, base: Modifier, proficiencyBonus: Modifier) {
        let diff = (modifier.modifier - base.modifier)
        let (quot, rem) = diff.quotientAndRemainder(dividingBy: proficiencyBonus.modifier)
        if rem == 0 {
            self = .times(quot)
        } else {
            self = .custom(modifier)
        }
    }

    mutating func makeRelative(base: Modifier, proficiencyBonus: Modifier) {
        self = .init(
            modifier: self.modifier(proficiencyBonus: proficiencyBonus),
            base: base,
            proficiencyBonus: proficiencyBonus
        )
    }
}

public extension StatBlock {
    static var `default`: StatBlock {
        StatBlock(name: "", size: nil, type: nil, subtype: nil, alignment: nil, armorClass: nil, armor: [], hitPointDice: nil, hitPoints: nil, movement: nil, abilityScores: nil, savingThrows: [:], skills: [:], damageVulnerabilities: nil, damageResistances: nil, damageImmunities: nil, conditionImmunities: nil, senses: nil, languages: nil, challengeRating: nil, features: [], actions: [], reactions: [])
    }

    /// Updates the skills & savingThrows of this statBlock for a model change:
    /// the value of those dictionaries have become optional, where a nil value
    /// means that the stat should get a bonus according to the proficiency bonus (based on CR or level)
    ///
    /// This method replaces all non-nil values that are equal to the proficiency bonus-based
    /// value. (So that they will update when the CR or level or ability is updated)
    mutating func makeSkillAndSaveProficienciesRelative() {
        let proficiencyBonus = self.proficiencyBonus

        for s in skills.keys {
            skills[s]?.makeRelative(
                base: (abilityScores?.score(for: s.ability).modifier ?? 0),
                proficiencyBonus: proficiencyBonus
            )
        }

        for a in savingThrows.keys {
            savingThrows[a]?.makeRelative(
                base: (abilityScores?.score(for: a).modifier ?? 0),
                proficiencyBonus: proficiencyBonus
            )
        }
    }
}
