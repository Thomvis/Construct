// Generated using Sourcery 1.6.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

internal extension XMLCompendiumParser.DocumentElement {
    init?(startElement: String) {
        switch startElement {
        case "compendium": self = .compendium(nil)
        default: return nil
        }
    }

    func didStartElement(_ element: String) -> Self? {
        switch self {
        case .compendium(let child?):
            return child.didStartElement(element).map { .compendium($0) }
        case .compendium(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement(startElement: element) {
                return .compendium(child)
            }
            return nil
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        case .compendium(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .compendium(child))
            }
        default:
            if self == Self(startElement: element) {
                return (true, nil)
            }
        }
        return (false, nil)
    }

    var elementName: String {
        switch self {
        case .compendium: return "compendium"
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .compendium(let child): return child
        }
    }

}
internal extension XMLCompendiumParser.DocumentElement.CompendiumElement {
    init?(startElement: String) {
        switch startElement {
        case "monster": self = .monster(nil)
        case "spell": self = .spell(nil)
        default: return nil
        }
    }

    func didStartElement(_ element: String) -> Self? {
        switch self {
        case .monster(let child?):
            return child.didStartElement(element).map { .monster($0) }
        case .monster(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement(startElement: element) {
                return .monster(child)
            }
            return nil
        case .spell(let child?):
            return child.didStartElement(element).map { .spell($0) }
        case .spell(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.SpellElement(startElement: element) {
                return .spell(child)
            }
            return nil
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        case .monster(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .monster(child))
            }
        case .spell(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .spell(child))
            }
        default:
            if self == Self(startElement: element) {
                return (true, nil)
            }
        }
        return (false, nil)
    }

    var elementName: String {
        switch self {
        case .monster: return "monster"
        case .spell: return "spell"
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .monster(let child): return child
        case .spell(let child): return child
        }
    }

}
internal extension XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement {
    init?(startElement: String) {
        switch startElement {
        case "name": self = .name
        case "size": self = .size
        case "type": self = .type
        case "alignment": self = .alignment
        case "ac": self = .ac
        case "hp": self = .hp
        case "speed": self = .speed
        case "str": self = .str
        case "dex": self = .dex
        case "con": self = .con
        case "int": self = .int
        case "wis": self = .wis
        case "cha": self = .cha
        case "save": self = .save
        case "skill": self = .skill
        case "resist": self = .resist
        case "vulnerable": self = .vulnerable
        case "immune": self = .immune
        case "conditionImmune": self = .conditionImmune
        case "senses": self = .senses
        case "passive": self = .passive
        case "languages": self = .languages
        case "cr": self = .cr
        case "trait": self = .trait(nil)
        case "action": self = .action(nil)
        case "legendary": self = .legendary(nil)
        case "reaction": self = .reaction(nil)
        case "spells": self = .spells
        case "slots": self = .slots
        case "description": self = .description
        case "environment": self = .environment
        default: return nil
        }
    }

    func didStartElement(_ element: String) -> Self? {
        switch self {
        case .trait(let child?):
            return child.didStartElement(element).map { .trait($0) }
        case .trait(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement(startElement: element) {
                return .trait(child)
            }
            return nil
        case .action(let child?):
            return child.didStartElement(element).map { .action($0) }
        case .action(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement(startElement: element) {
                return .action(child)
            }
            return nil
        case .legendary(let child?):
            return child.didStartElement(element).map { .legendary($0) }
        case .legendary(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement(startElement: element) {
                return .legendary(child)
            }
            return nil
        case .reaction(let child?):
            return child.didStartElement(element).map { .reaction($0) }
        case .reaction(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement(startElement: element) {
                return .reaction(child)
            }
            return nil
        default: return nil
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        case .trait(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .trait(child))
            }
        case .action(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .action(child))
            }
        case .legendary(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .legendary(child))
            }
        case .reaction(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .reaction(child))
            }
        default:
            if self == Self(startElement: element) {
                return (true, nil)
            }
        }
        return (false, nil)
    }

    var elementName: String {
        switch self {
        case .name: return "name"
        case .size: return "size"
        case .type: return "type"
        case .alignment: return "alignment"
        case .ac: return "ac"
        case .hp: return "hp"
        case .speed: return "speed"
        case .str: return "str"
        case .dex: return "dex"
        case .con: return "con"
        case .int: return "int"
        case .wis: return "wis"
        case .cha: return "cha"
        case .save: return "save"
        case .skill: return "skill"
        case .resist: return "resist"
        case .vulnerable: return "vulnerable"
        case .immune: return "immune"
        case .conditionImmune: return "conditionImmune"
        case .senses: return "senses"
        case .passive: return "passive"
        case .languages: return "languages"
        case .cr: return "cr"
        case .trait: return "trait"
        case .action: return "action"
        case .legendary: return "legendary"
        case .reaction: return "reaction"
        case .spells: return "spells"
        case .slots: return "slots"
        case .description: return "description"
        case .environment: return "environment"
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .name: return nil
        case .size: return nil
        case .type: return nil
        case .alignment: return nil
        case .ac: return nil
        case .hp: return nil
        case .speed: return nil
        case .str: return nil
        case .dex: return nil
        case .con: return nil
        case .int: return nil
        case .wis: return nil
        case .cha: return nil
        case .save: return nil
        case .skill: return nil
        case .resist: return nil
        case .vulnerable: return nil
        case .immune: return nil
        case .conditionImmune: return nil
        case .senses: return nil
        case .passive: return nil
        case .languages: return nil
        case .cr: return nil
        case .trait(let child): return child
        case .action(let child): return child
        case .legendary(let child): return child
        case .reaction(let child): return child
        case .spells: return nil
        case .slots: return nil
        case .description: return nil
        case .environment: return nil
        }
    }

}
internal extension XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement {
    init?(startElement: String) {
        switch startElement {
        case "name": self = .name
        case "text": self = .text
        case "attack": self = .attack
        case "special": self = .special
        default: return nil
        }
    }

    func didStartElement(_ element: String) -> Self? {
        switch self {
        default: return nil
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        default:
            if self == Self(startElement: element) {
                return (true, nil)
            }
        }
        return (false, nil)
    }

    var elementName: String {
        switch self {
        case .name: return "name"
        case .text: return "text"
        case .attack: return "attack"
        case .special: return "special"
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .name: return nil
        case .text: return nil
        case .attack: return nil
        case .special: return nil
        }
    }

}
internal extension XMLCompendiumParser.DocumentElement.CompendiumElement.SpellElement {
    init?(startElement: String) {
        switch startElement {
        case "name": self = .name
        case "classes": self = .classes
        case "level": self = .level
        case "school": self = .school
        case "ritual": self = .ritual
        case "time": self = .time
        case "range": self = .range
        case "components": self = .components
        case "duration": self = .duration
        case "text": self = .text
        default: return nil
        }
    }

    func didStartElement(_ element: String) -> Self? {
        switch self {
        default: return nil
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        default:
            if self == Self(startElement: element) {
                return (true, nil)
            }
        }
        return (false, nil)
    }

    var elementName: String {
        switch self {
        case .name: return "name"
        case .classes: return "classes"
        case .level: return "level"
        case .school: return "school"
        case .ritual: return "ritual"
        case .time: return "time"
        case .range: return "range"
        case .components: return "components"
        case .duration: return "duration"
        case .text: return "text"
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .name: return nil
        case .classes: return nil
        case .level: return nil
        case .school: return nil
        case .ritual: return nil
        case .time: return nil
        case .range: return nil
        case .components: return nil
        case .duration: return nil
        case .text: return nil
        }
    }

}
