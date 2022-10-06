//
//  Open5eSpellDataSourceReader.swift
//  Construct
//
//  Created by Thomas Visser on 12/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels

public class Open5eSpellDataSourceReader: CompendiumDataSourceReader {
    public static let name = "Open5eSpellDataSourceReader"

    public let dataSource: CompendiumDataSource

    public init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    public func read() -> CompendiumDataSourceReaderJob {
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
        self.init(
            realm: realm,
            name: s.name,
            level: s.levelInt == 0 ? nil : s.levelInt,
            castingTime: s.castingTime,
            range: s.range,
            components: s.components.components(separatedBy: ",").compactMap {
                switch $0.trimmingCharacters(in: CharacterSet.whitespaces) {
                case "V": return .verbal
                case "S": return .somatic
                case "M": return .material
                default: return nil
                }
            },
            ritual: s.ritual == "yes",
            duration: s.duration,
            school: s.school,
            concentration: s.concentration == "yes",
            description: ParseableSpellDescription(input: s.desc),
            higherLevelDescription: s.higherLevel,
            classes: s.spellClass.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) },
            material: s.material
        )
    }
}
