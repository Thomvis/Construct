//
//  XMLMonsterDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 09/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

class XMLMonsterDataSourceReader: CompendiumDataSourceReader {
    static let name = "XMLMonsterDataSourceReader"

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
                XMLCompendiumParser.parse(data: data, element: .compendium(.monster(nil))).compactMap { content in
                    Monster(elementContent: content, realm: .core)
                }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
        }
    }
}

final class XMLCompendiumParser: NSObject {
    static var trimWhitespace = true

    private let parser: XMLParser
    private var state: State = State(current: nil, unrecognized: [])

    private let outputElement: DocumentElement
    private var outputContent: [State.ElementContent] = []

    private init(data: Data, element: DocumentElement) {
        parser = XMLParser(data: data)
        outputElement = element

        super.init()

        parser.delegate = self
    }

    static func parse(data: Data, element: DocumentElement) -> AnyPublisher<State.ElementContent, Error> {
        return Deferred { () -> AnyPublisher<State.ElementContent, Error> in
            let parser = XMLCompendiumParser(data: data, element: element)
            parser.parser.parse()

            return Publishers.Sequence(sequence: parser.outputContent).eraseToAnyPublisher()
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

                if outputElement == current {
                    if let content = endedElementContent {
                        outputContent.append(content)
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

    init?(elementContent c: XMLCompendiumParser.State.ElementContent, realm: CompendiumItemKey.Realm) {
        guard let stats = StatBlock(elementContent: c),
              let cr = stats.challengeRating
        else {
            return nil
        }
        self.init(realm: realm, stats: stats, challengeRating: cr)
    }
}

extension StatBlock {
    init?(elementContent c: XMLCompendiumParser.State.ElementContent) {
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

            features: parseTraits(M.trait(nil), CreatureFeature.init),
            actions: parseTraits(M.action(nil), CreatureAction.init),
            reactions: parseTraits(M.reaction(nil), CreatureAction.init),
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

                return Legendary(
                    description: description,
                    actions: parseTraits(M.legendary(nil), CreatureAction.init) // this will skip the description element because it doesn't have a name
                )
            }
        )
    }
}
