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
import AsyncAlgorithms

public class Open5eSpellDataSourceReader: CompendiumDataSourceReader {
    public static let name = "Open5eSpellDataSourceReader"

    public let dataSource: CompendiumDataSource

    public init(dataSource: CompendiumDataSource) {
        self.dataSource = dataSource
    }

    public func read() async throws -> CompendiumDataSourceReaderJob {
        return try Job(data: await dataSource.read())
    }

    class Job: CompendiumDataSourceReaderJob {
        let output: AsyncStream<CompendiumDataSourceReaderOutput>

        init(data: Data) throws {
            let spells: [O5e.Spell]
            do {
                spells = try JSONDecoder().decode([O5e.Spell].self, from: data)
            } catch {
                throw CompendiumDataSourceReaderError.incompatibleDataSource
            }

            output = spells.async.map { s in
                guard let spell = Spell(open5eSpell: s, realm: .core) else { return CompendiumDataSourceReaderOutput.invalidItem(String(describing: s)) }
                return .item(spell)
            }.stream
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
