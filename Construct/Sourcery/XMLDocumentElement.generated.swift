// Generated using Sourcery 1.0.0 — https://github.com/krzysztofzablocki/Sourcery
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
        }
    }

    func didEndElement(_ element: String) -> (Bool, Self?) {
        switch self {
        case .monster(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .monster(child))
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
        }
    }

    var inner: XMLDocumentElement? {
        switch self {
        case .monster(let child): return child
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
        case "lengendary": self = .lengendary(nil)
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
        case .lengendary(let child?):
            return child.didStartElement(element).map { .lengendary($0) }
        case .lengendary(nil):
            if let child = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement.TraitElement(startElement: element) {
                return .lengendary(child)
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
        case .lengendary(let child?):
            let (success, child) = child.didEndElement(element)
            if success {
                return (true, .lengendary(child))
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
        case .lengendary: return "lengendary"
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
        case .lengendary(let child): return child
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
