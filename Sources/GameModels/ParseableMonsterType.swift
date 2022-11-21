//
//  ParseableMonsterType.swift
//  
//
//  Created by Thomas Visser on 19/11/2022.
//

import Foundation
import Helpers

public typealias ParseableMonsterType = Parseable<String, MonsterType>

public extension ParseableMonsterType {
    var localizedDisplayName: String {
        result?.value?.localizedDisplayName ?? input.capitalized
    }

    init(from type: MonsterType) {
        self.init(
            input: type.rawValue,
            result: ParserResult(
                value: type,
                parserName: String(describing: MonsterTypeDomainParser.self),
                version: MonsterTypeDomainParser.version,
                modelVersion: MonsterType.version
            )
        )
    }
}

extension MonsterType: DomainModel {
    public static let version: String = "1"
}
