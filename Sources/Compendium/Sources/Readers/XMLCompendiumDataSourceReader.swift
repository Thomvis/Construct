//
//  XMLCompendiumDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 09/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels
import Helpers

public class XMLCompendiumDataSourceReader: CompendiumDataSourceReader {
    public static let name = "XMLMonsterDataSourceReader"

    public var dataSource: any CompendiumDataSource<Data>
    let generateUUID: () -> UUID

    public init(dataSource: any CompendiumDataSource<Data>, generateUUID: @escaping () -> UUID) {
        self.dataSource = dataSource
        self.generateUUID = generateUUID
    }

    public func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        try dataSource.read().flatMap { data in
            let items = XMLCompendiumParser.parse(data: data, elements: [.compendium(.monster(nil)), .compendium(.spell(nil))]).values

            return items
                .mapError { error in
                    CompendiumDataSourceReaderError.incompatibleDataSource
                }
                .map { (element, content) -> CompendiumDataSourceReaderOutput in
                    switch (element) {
                    case .compendium(.monster(nil)):
                        if let monster = Monster(elementContent: content, realm: .init(realmId), generateUUID: self.generateUUID) {
                            return .item(monster)
                        }
                    case .compendium(.spell(nil)):
                        if let spell = Spell(elementContent: content, realm: .init(realmId)) {
                            return .item(spell)
                        }
                    default: break
                    }
                    return .invalidItem(String(describing: element))
                }
        }.stream
    }
}

final class XMLCompendiumParser: NSObject {
    static var trimWhitespace = true

    private let parser: XMLParser
    private var state: State = State(current: nil, unrecognized: [])

    private let outputElements: [DocumentElement]
    private var outputContent: [(DocumentElement, State.ElementContent)] = []

    private init(data: Data, elements: [DocumentElement]) {
        parser = XMLParser(data: data)
        outputElements = elements

        super.init()

        parser.delegate = self
    }

    func parse() -> Result<[(DocumentElement, State.ElementContent)], Error> {
        parser.parse()

        if let error = parser.parserError {
            return .failure(error)
        }

        return .success(outputContent)
    }

    static func parse(data: Data, elements: [DocumentElement]) -> AnyPublisher<(DocumentElement, State.ElementContent), Error> {
        return Deferred {
            XMLCompendiumParser(data: data, elements: elements).parse().publisher.flatMap { elements in
                Publishers.Sequence<[(DocumentElement, State.ElementContent)], Error>(sequence: elements)
            }
        }.eraseToAnyPublisher()
    }

    func didStartElement(_ element: String) {
        guard state.unrecognized.isEmpty else {
            state.unrecognized.append(element)
            return
        }

        if let current = state.current {
            if let new = current.didStartElement(element) {
                self.state.current = new
            } else {
                state.unrecognized.append(element)
            }
        } else if element == DocumentElement.compendium(nil).elementName {
            state.current = .compendium(nil)
        } else {
            state.unrecognized.append(element)
        }
    }

    func foundCharacters(_ string: String) {
        let effectiveString: String
        if Self.trimWhitespace {
            effectiveString = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } else {
            effectiveString = string
        }

        if !effectiveString.isEmpty {
            appendContent(.string(effectiveString))
        }
    }

    private func appendContent(_ content: State.ElementContent) {
        guard state.unrecognized.isEmpty else {
            // ignoring content for unrecognized elements
            return
        }

        guard let current = state.current else {
            // ignoring content outside of document element
            return
        }

        if var elementContent = state.content[current] {
            elementContent.append(content)
            state.content[current] = elementContent
        } else {
            state.content[current] = content
        }
    }

    func didEndElement(_ element: String) {
        if let last = state.unrecognized.last {
            if last == element {
                state.unrecognized.removeLast()
            } else {
                assertionFailure("Unexpected element did end, expecting \(last)")
            }
        } else if let current = state.current {
            let (success, new) = current.didEndElement(element)
            if success {
                let endedElementContent = state.content[current]
                state.content[current] = nil

                self.state.current = new

                if outputElements.contains(current) {
                    if let content = endedElementContent {
                        outputContent.append((current, content))
                    }
                    appendContent(.element(element, nil))
                } else {
                    appendContent(.element(element, endedElementContent))
                }
            } else {
                assertionFailure("Unexpected element did end, current element \(current)")
            }
        } else {
            assertionFailure("Unexpected element did end. No current element.")
        }
    }

    struct State {
        var current: DocumentElement?
        var unrecognized: [String]

        var content: [DocumentElement: ElementContent] = [:]

        indirect enum ElementContent {
            case string(String)
            case element(String, ElementContent?)
            case compound([ElementContent])

            var stringValue: String? {
                if case .string(let string) = self {
                    return string
                }
                return nil
            }

            var intValue: Int? {
                stringValue.flatMap { Int($0) }
            }

            mutating func append(_ content: ElementContent) {
                if case .string(let lhs) = self, case .string(let rhs) = content {
                    self = .string(lhs + rhs)
                } else if case .compound(let elements) = self {
                    if case .string(let lhs) = elements.last, case .string(let rhs) = content {
                        self = .compound(elements.dropLast() + [.string(lhs + rhs)])
                    } else {
                        self = .compound(elements + [content])
                    }
                } else {
                    self = .compound([self, content])
                }
            }

            private var asContentList: [ElementContent] {
                switch self {
                case .string, .element: return [self]
                case .compound(let contents): return contents
                }
            }

            subscript(first element: XMLDocumentElement) -> ElementContent? {
                get {
                    guard let match = asContentList.lazy.compactMap({ content -> ElementContent? in
                        if case .element(let name, let elementContent) = content, name == element.elementName {
                            return elementContent
                        }
                        return nil
                    }).first else {
                        return nil
                    }

                    if let inner = element.inner {
                        return match[first: inner]
                    } else {
                        return match
                    }
                }
            }

            subscript(any element: XMLDocumentElement) -> [ElementContent] {
                get {
                    Array(asContentList.lazy.compactMap({ content -> ElementContent? in
                        if case .element(let name, let elementContent) = content, name == element.elementName {
                            return elementContent
                        }
                        return nil
                    }).flatMap { match -> [ElementContent] in
                        if let inner = element.inner {
                            return match[any: inner]
                        } else {
                            return [match]
                        }
                    })
                }
            }
        }
    }

    enum DocumentElement: XMLDocumentElement, Hashable {
        case compendium(CompendiumElement?)

        enum CompendiumElement: XMLDocumentElement, Hashable {
            case monster(MonsterElement?)
            case spell(SpellElement?)

            enum MonsterElement: XMLDocumentElement, Hashable {
                case name
                case size
                case type
                case alignment
                case ac
                case hp
                case speed
                case str
                case dex
                case con
                case int
                case wis
                case cha
                case save
                case skill
                case resist
                case vulnerable
                case immune
                case conditionImmune
                case senses
                case passive
                case languages
                case cr
                case trait(TraitElement?)
                case action(TraitElement?)
                case legendary(TraitElement?)
                case reaction(TraitElement?)
                case spells
                case slots
                case description
                case environment

                enum TraitElement: XMLDocumentElement, Hashable {
                    case name
                    case text
                    case attack
                    case special
                }
            }

            enum SpellElement: XMLDocumentElement, Hashable {
                case name
                case classes
                case level
                case school
                case ritual
                case time
                case range
                case components
                case duration
                case text
            }
        }
    }
}

protocol XMLDocumentElement {
    var elementName: String { get }
    var inner: XMLDocumentElement? { get }
}

extension XMLCompendiumParser: XMLParserDelegate {

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        didStartElement(elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        foundCharacters(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        didEndElement(elementName)
    }

    func parserDidEndDocument(_ parser: XMLParser) {

    }

    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {

    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("error")
    }

}

fileprivate typealias M = XMLCompendiumParser.DocumentElement.CompendiumElement.MonsterElement

extension Monster {

    init?(elementContent c: XMLCompendiumParser.State.ElementContent, realm: CompendiumItemKey.Realm, generateUUID: () -> UUID) {
        guard let stats = StatBlock(elementContent: c, generateUUID: generateUUID),
              let cr = stats.challengeRating
        else {
            return nil
        }
        self.init(realm: realm, stats: stats, challengeRating: cr)
    }
}

fileprivate typealias S = XMLCompendiumParser.DocumentElement.CompendiumElement.SpellElement

extension Spell {
    init?(elementContent c: XMLCompendiumParser.State.ElementContent, realm: CompendiumItemKey.Realm) {

        guard let name = c[first: S.name]?.stringValue?.nonEmptyString,
              let level = c[first: S.level]?.intValue,
              let castingTime = c[first: S.time]?.stringValue,
              let range = c[first: S.range]?.stringValue,
              let componentsString = c[first: S.components]?.stringValue,
              let (components, material) = componentParser.run(componentsString),
              let ritualString = c[first: S.ritual]?.stringValue,
              let durationString = c[first: S.duration]?.stringValue,
              let schoolAbbreviation = c[first: S.school]?.stringValue,
              let school = schoolsOfMagic[schoolAbbreviation],
              let text = c[first: S.text]?.stringValue,
              let classesString = c[first: S.classes]?.stringValue else {
                  return nil
              }

        // duration contains concentration
        let (concentration, duration) = durationParser.run(durationString) ?? (false, durationString)
        let (description, higherLevels, _) = textParser.run(text) ?? (text, nil, nil)
        let classes = classesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        self.init(
            realm: realm,
            name: name,
            level: level == 0 ? nil : level,
            castingTime: castingTime,
            range: range,
            components: components,
            ritual: ritualString == "YES",
            duration: duration,
            school: school,
            concentration: concentration,
            description: ParseableSpellDescription(input: description),
            higherLevelDescription: higherLevels,
            classes: classes,
            material: material
        )
    }
}

extension StatBlock {
    init?(elementContent c: XMLCompendiumParser.State.ElementContent, generateUUID: () -> UUID) {
        guard let name = c[first: M.name]?.stringValue?.nonEmptyString,
              let type = c[first: M.type]?.stringValue,
              let ac = c[first: M.ac]?.stringValue,
              let hp = c[first: M.hp]?.stringValue,
              let speed = c[first: M.speed]?.stringValue,

              let str = (c[first: M.str]?.stringValue).flatMap({ Int($0) }),
              let dex = (c[first: M.dex]?.stringValue).flatMap({ Int($0) }),
              let con = (c[first: M.con]?.stringValue).flatMap({ Int($0) }),
              let int = (c[first: M.int]?.stringValue).flatMap({ Int($0) }),
              let wis = (c[first: M.wis]?.stringValue).flatMap({ Int($0) }),
              let cha = (c[first: M.cha]?.stringValue).flatMap({ Int($0) }),

              let crString = c[first: M.cr]?.stringValue,
              let cr = Fraction(rawValue: crString) else {
            return nil
        }

        let abilities = AbilityScores(
            strength: .init(str),
            dexterity: .init(dex),
            constitution: .init(con),
            intelligence: .init(int),
            wisdom: .init(wis),
            charisma: .init(cha)
        )

        let parsedType = DataSourceReaderParsers.typeParser.run(type)
        if parsedType == nil {
            print("Could not parse type: \(type)")
        }

        let parsedAC = DataSourceReaderParsers.acParser.run(ac)
        let parsedHP = DataSourceReaderParsers.hpParser.run(hp)
        let parsedMovement = DataSourceReaderParsers.movementDictParser.run(speed)

        func parseModifierList<S>(_ element: M, key: (String) -> S?) -> [S: Modifier] {
            (c[first: element]?.stringValue)
                .flatMap {
                    DataSourceReaderParsers.modifierListParser.run($0)
                }.flatMap {
                    Dictionary(
                        uniqueKeysWithValues: $0.compactMap { t in
                            key(t.0).map { ($0, Modifier(modifier: t.1)) }
                        }
                    )
                } ?? [:]
        }

        func parseTraits<T>(content: XMLCompendiumParser.State.ElementContent = c, _ element: M, _ toModel: (String, String) -> T) -> [T] {
            content[any: element].compactMap { content in
                guard let name = content[first: M.TraitElement.name]?.stringValue,
                      let description = content[any: M.TraitElement.text].compactMap({ $0.stringValue }).nonEmptyArray?.joined(separator: "\n") else { return nil }
                return toModel(name, description)
            }
        }

        self.init(
            name: name,
            size: (c[first: M.size]?.stringValue).flatMap { CreatureSize(englishName: $0) },
            type: parsedType?.1.nonEmptyString,
            subtype: parsedType?.2?.nonEmptyString,
            alignment: (c[first: M.alignment]?.stringValue).flatMap { Alignment(englishName: $0) },

            armorClass: parsedAC?.0,
            armor: parsedAC.flatMap { ac in ac.1.map { name in (ac.0, name) } }.map { [Armor(name: $0.1, armorClass: $0.0)] } ?? [],
            hitPointDice: parsedHP?.1,
            hitPoints: parsedHP?.0,
            movement: parsedMovement,

            abilityScores: abilities,

            savingThrows: parseModifierList(M.save, key: Ability.init(abbreviation:)),
            skills: parseModifierList(M.skill, key: { Skill(rawValue: $0.lowercased()) }),
            initiative: nil,

            damageVulnerabilities: c[first: M.vulnerable]?.stringValue,
            damageResistances: c[first: M.resist]?.stringValue,
            damageImmunities: c[first: M.immune]?.stringValue,
            conditionImmunities: c[first: M.conditionImmune]?.stringValue,

            senses: c[first: M.senses]?.stringValue,
            languages: c[first: M.languages]?.stringValue,

            challengeRating: cr,

            features: parseTraits(M.trait(nil), { CreatureFeature(id: generateUUID(), name: $0, description: $1) }),
            actions: parseTraits(M.action(nil), { CreatureAction(id: generateUUID(), name: $0, description: $1) }),
            reactions: parseTraits(M.reaction(nil), { CreatureAction(id: generateUUID(), name: $0, description: $1) }),
            legendary: with(c[any: M.legendary(nil)]) { legendaryElements in
                let description: String?
                if let first = legendaryElements.first,
                   first[first: M.TraitElement.name] == nil,
                   let text = first[any: M.TraitElement.text].compactMap({ $0.stringValue }).nonEmptyArray?.joined(separator: "\n")
                {
                    description = text
                } else {
                    description = nil
                }

                let actions = parseTraits(M.legendary(nil), { CreatureAction(id: generateUUID(), name: $0, description: $1) }) // this will skip the description element because it doesn't have a name

                guard description != nil || !actions.isEmpty else { return nil }

                return Legendary(
                    description: description,
                    actions: actions.map(ParseableCreatureAction.init)
                )
            }
        )
    }
}

/// Separates concentration and duration from the duration input
/// Parses "Concentration, up to 1 minute" as well as "Up to 1 minute"
fileprivate let durationParser: Parser<(Bool, String)> = either(
    zip(
        string("Concentration,").trimming(horizontalWhitespace()),
        remainder()
    ).map { (true, $0.1) },
    remainder().map { (false, $0) }
)

/// Separates the spell description and the higher level description
/// from the text input
fileprivate let textParser: Parser<(description: String, higherLevels: String?, source: String?)> = {
    let source = zip(
        string("Source: "),
        skip(until: either(verticalWhitespace(), end().map { "" })).map { $0.0 }
    ).map {
        $0.1
    }

    let highLevel = zip(
        string("At Higher Levels:"),
        skip(until: verticalWhitespace()).map { $0.0 },
        skip(until: either(source.map { Optional.some($0) }, end().map { Optional.none }))
    ).map {
        $0.2
    }

    return skip(until: either(
        highLevel.map { (Optional.some($0.0), $0.1) },
        source.map { (Optional.none, $0) },
        end().map { (Optional.none, Optional.none) })
    ).map {
        (
            description: $0.0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            higherLevels: $0.1.0?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            source: $0.1.1?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        )
    }
}()

fileprivate let componentParser: Parser<([Spell.Component], String?)> = oneOrMore(
    zip(
        either(
            string("V").map { _ in (Spell.Component.verbal, Optional<String>.none) },
            string("S").map { _ in (Spell.Component.somatic, Optional<String>.none) },
            zip(
                string("M").map { _ in Spell.Component.material },
                zip(
                    string("(").trimming(horizontalWhitespace()),
                    skip(until: string(")")).map { String($0.0[..<$0.0.index($0.0.endIndex, offsetBy: -1)]) }
                )
                .optional()
            )
            .map { ($0.0, $0.1?.1) }
        ),
        string(",").trimming(horizontalWhitespace()).optional()
    )
    .map { ($0.0) }
).map { (list: [(Spell.Component, Optional<String>)]) in
    list.reduce((Array<Spell.Component>(), Optional<String>.none)) { acc, elem in
        (acc.0 + [elem.0], acc.1 ?? elem.1)
    }
}

fileprivate let schoolsOfMagic: [String:String] = [
    "A": "Abjuration",
    "C": "Conjuration",
    "D": "Divination",
    "EN": "Enchantment",
    "EV": "Evocation",
    "N": "Necromancy",
    "T": "Transmutation"
]
