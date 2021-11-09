//
//  CreatureFeatureDomainParser.swift
//  Construct
//
//  Created by Thomas Visser on 09/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

struct CreatureFeatureDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureFeature) -> ParsedCreatureFeature? {
        return nil
    }
}

enum ParsedCreatureFeature: Codable, Hashable {

    case spellcasting(Spellcasting)

    var annotations: [Int] {
        [] // TODO
    }
}

extension ParsedCreatureFeature {
    struct Spellcasting: Hashable, Codable {
        let innate: Bool
        let slotsByLevel: [Int:Int]
        let spells: [Located<String>]
    }
}

typealias ParseableCreatureFeature = Parseable<CreatureFeature, ParsedCreatureFeature, CreatureFeatureDomainParser>

extension ParseableCreatureFeature {
    var name: String { input.name }
    var description: String { input.description }
}
