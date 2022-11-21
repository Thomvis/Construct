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
import CasePaths
import IdentifiedCollections

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
    public var savingThrows: [Ability: Modifier?]
    /// if the value is nil, the default proficiency bonus applies
    public var skills: [Skill: Modifier?]
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

    public init(name: String, size: CreatureSize? = nil, type: String? = nil, subtype: String? = nil, alignment: Alignment? = nil, armorClass: Int? = nil, armor: [Armor], hitPointDice: DiceExpression? = nil, hitPoints: Int? = nil, movement: [MovementMode : Int]? = nil, abilityScores: AbilityScores? = nil, savingThrows: [Ability : Modifier], skills: [Skill : Modifier], initiative: Initiative? = nil, damageVulnerabilities: String? = nil, damageResistances: String? = nil, damageImmunities: String? = nil, conditionImmunities: String? = nil, senses: String? = nil, languages: String? = nil, challengeRating: Fraction? = nil, features: [CreatureFeature], actions: [CreatureAction], reactions: [CreatureAction], legendary: Legendary? = nil) {
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
        self.features = IdentifiedArrayOf(uniqueElements: features.map(ParseableCreatureFeature.init(input:)))
        self.actions = IdentifiedArrayOf(uniqueElements: actions.map(ParseableCreatureAction.init(input:)))
        self.reactions = IdentifiedArrayOf(uniqueElements: reactions.map(ParseableCreatureAction.init(input:)))
        self.legendary = legendary
    }

    public func savingThrowModifier(_ ability: Ability) -> Modifier {
        switch savingThrows[ability] {
        case let explicit??: // override
            return explicit
        case .some(.none): // default proficiency
            return (abilityScores?.score(for: ability).modifier ?? 0) + proficiencyBonus
        case nil: // no proficiency
            return abilityScores?.score(for: ability).modifier ?? 0
        }
    }

    public func skillModifier(_ skill: Skill) -> Modifier {
        switch skills[skill] {
        case let explicit??: // override
            return explicit
        case .some(.none): // default proficiency
            return (abilityScores?.score(for: skill.ability).modifier ?? 0) + proficiencyBonus
        case nil: // no proficiency
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

    public struct Legendary: Codable, Hashable {
        public var description: String?
        public var actions: IdentifiedArrayOf<ParseableCreatureAction>

        public init(description: String? = nil, actions: [ParseableCreatureAction]) {
            self.description = description
            self.actions = IdentifiedArrayOf(uniqueElements: actions)
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
                if legendary != nil {
                    legendary?.actions = newActions.identified
                } else {
                    legendary = Legendary(actions: newActions)
                }
            default:
                assertionFailure("Failed setting a StatBlock's itemsOfType due to a type mismatch")
            }
        }
    }
}

public extension StatBlock {
    static var `default`: StatBlock {
        StatBlock(name: "", size: nil, type: nil, subtype: nil, alignment: nil, armorClass: nil, armor: [], hitPointDice: nil, hitPoints: nil, movement: nil, abilityScores: nil, savingThrows: [:], skills: [:], damageVulnerabilities: nil, damageResistances: nil, damageImmunities: nil, conditionImmunities: nil, senses: nil, languages: nil, challengeRating: nil, features: [], actions: [], reactions: [])
    }
}
