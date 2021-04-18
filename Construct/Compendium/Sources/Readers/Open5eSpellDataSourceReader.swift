//
//  Open5eSpellDataSourceReader.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 12/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

import Foundation
import Combine

class Open5eSpellDataSourceReader: CompendiumDataSourceReader {
    static let name = "Open5eSpellDataSourceReader"

    let dataSource: CompendiumDataSource

    init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    func read() -> CompendiumDataSourceReaderJob {
        return Job(data: dataSource.read())
    }

    class Job: CompendiumDataSourceReaderJob {
        let output: AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError>

        init(data: AnyPublisher<Data, CompendiumDataSourceError>) {
            output = data
                .mapError { CompendiumDataSourceReaderError.dataSource($0) }
                .flatMap { data -> AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError> in
                    do {
                        let spells = try JSONDecoder().decode([O5e.Spell].self, from: data)
                        return Publishers.Sequence(sequence: spells.map { m in
                            guard let spell = Spell(open5eSpell: m, realm: .core) else { return CompendiumDataSourceReaderOutput.invalidItem(String(describing: m)) }
                            return .item(spell)
                        }).eraseToAnyPublisher()
                    } catch {
                        return Fail(error: CompendiumDataSourceReaderError.incompatibleDataSource).eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        }
    }

}

private extension Spell {
    init?(open5eSpell s: O5e.Spell, realm: CompendiumItemKey.Realm) {
        self.realm = realm
        self.name = s.name

        self.level = s.levelInt == 0 ? nil : s.levelInt
        self.castingTime = s.castingTime
        self.range = s.range
        self.components = s.components.components(separatedBy: ",").compactMap {
            switch $0.trimmingCharacters(in: CharacterSet.whitespaces) {
            case "V": return .verbal
            case "S": return .somatic
            case "M": return .material
            default: return nil
            }
        }
        self.ritual = s.ritual == "yes"
        self.duration = s.duration
        self.school = s.school
        self.concentration = s.concentration == "yes"

        self.description = s.desc
        self.higherLevelDescription = s.higherLevel

        self.classes = s.spellClass.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        self.material = s.material
    }
}
