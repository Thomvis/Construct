//
//  SharedLiterals.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import Helpers

extension CreatureSize {
    init?(englishName s: String) {
        switch s.lowercased() {
        case "tiny", "t": self = .tiny
        case "small", "s": self = .small
        case "medium", "m": self = .medium
        case "large", "l": self = .large
        case "huge", "h": self = .huge
        case "gargantuan", "g": self = .gargantuan
        default: return nil
        }
    }
}

extension Alignment.Moral {
    init?(englishName s: String) {
        switch s {
        case "lawful": self = .lawful
        case "neutral": self = .neutral
        case "chaotic": self = .chaotic
        default: return nil
        }
    }
}

extension Alignment.Ethic {
    init?(englishName s: String) {
        switch s {
        case "good": self = .good
        case "neutral": self = .neutral
        case "evil": self = .evil
        default: return nil
        }
    }
}

extension Alignment {
    init?(englishName s: String) {
        switch s {
        case "any alignment":
            self = .any
            return
        case "unaligned":
            self = .unaligned
            return
        case "neutral":
            self = .neutral
            return
        default: break
        }

        let components = s.split(separator: " ")
        if components.count == 2, let moral = Alignment.Moral(englishName: String(components[0])), let ethic = Alignment.Ethic(englishName: String(components[1])) {
            self = .both(moral, ethic)
            return
        }

        // FIXME
        return nil
    }
}

extension MovementMode {
    init?(englishName s: String) {
        switch s.lowercased() {
        case "walk": self = .walk
        case "fly": self = .fly
        case "swim": self = .swim
        case "climb": self = .climb
        case "burrow": self = .burrow
        default: return nil
        }
    }
}

enum DataSourceReaderParsers {
    static let movementTupleParser = any(
        either(
            // walk 30 ft.
            zip(
                word().optional(),
                char(" "),
                int().log("int"),
                string("ft.").skippingAnyBefore(),
                either(string(",").trimming(horizontalWhitespace()).map { _ in () }, end())
            ).map {
                ($0.2, $0.0)
            },
            // 30 ft. walk
            zip(
                int(),
                string("ft.").skippingAnyBefore(),
                zip(
                    char(" "),
                    word()
                ).optional(),
                either(string(",").trimming(horizontalWhitespace()).map { _ in () }, end())
            ).map {
                ($0.0, $0.2?.1)
            }
        ).flatMap { speed, modeString -> (MovementMode, Int)? in
            if let modeString = modeString {
                guard let mode = MovementMode(englishName: modeString) else { return nil }
                return (mode, speed)
            }
            return (.walk, speed)
        }
    )

    static let movementDictParser = movementTupleParser.flatMap { modes in
        Dictionary(modes) { lhs, rhs in lhs }
    }

    // Parses "12" and "12 (natural armor)"
    static let acParser = zip(
        int(),
        zip(
            string("(").skippingAnyBefore(),
            any(zip(word(), horizontalWhitespace().optional()).map { $0.0 }).joined(separator: " "),
            string(")")
        ).optional()
    ).map {
        ($0.0, $0.1?.1)
    }

    // Parses "225 (18d12+108)"
    static let hpParser = zip(
        int(),
        zip(
           char("(").skippingAnyBefore(),
           DiceExpressionParser.diceExpression(),
           char(")")
        ).optional()
    ).map { ($0.0, $0.1?.1) }

    // Parses "Dex +1, Cha +5" and "Perception +1, Stealth +5"
    static let modifierListParser = any(
        zip(
            word(),
            horizontalWhitespace(),
            either(char("-").map { _ in -1 }, char("+").map { _ in 1 }),
            int(),
            string(", ").optional()
        ).map { label, _, sign, num, _ in
            (label, sign * num)
        }
    )

    // Parses "(something)"
    static let parenthesizedStringParser: Parser<String> = char("(")
        .followed(by: any(character { $0 != ")" }).joined())
        .followed(by: char(")"))
        .map { $0.0.1 }
}

extension DataSourceReaderParsers {
    // Parses strings like:
    // - Medium dragon, unaligned
    // - M humanoid (gnoll), chaotic neutral
    // - Large beast, monster manual, neutral
    // Returns (size, creature type, subtype, alignment)
    static let typeParser: Parser<(CreatureSize?, String, String?, Alignment?)> = any(
        either(
            zip(
                either(
                    Self.alignmentParser.log("al"),
                    Self.sizeTypeParser.log("size")
                ),
                Self.endOfComponentParser.log("eoc")
            ).map { $0.0 },
            Self.skipComponentParser.log("skip")
        )
    ).map { $0.flatMap { $0} }.flatMap {
        guard let type = $0.type else { return nil }
        return ($0.size, type, $0.subtype, $0.alignment)
    }

    private static let sizeTypeParser: Parser<[TypeComponent]> = zip(
        // size (optional)
        zip(
            word(),
            horizontalWhitespace()
        ).flatMap { w, _ in
            CreatureSize(englishName: w).map { TypeComponent.size($0) }
        }.optional(),
        // type
        word().flatMap { w in
            TypeComponent.type(w)
        },
        // sub-type (optional)
        parenthesizedStringParser.map {
            TypeComponent.subtype($0)
        }.trimming(horizontalWhitespace()).optional()
    ).map { s, t, st in [s, t, st].compactMap { $0 } }

    private static let alignmentParser = skip(until: Self.endOfComponentParser).flatMap { component in
        Alignment(englishName: component.0).map { [TypeComponent.alignment($0)] }
    }

    private static let endOfComponentParser = char(",").followed(by: any(char(" "))).map { _ in () }.or(end())

    private static let skipComponentParser: Parser<[TypeComponent]> = skip(until: Self.endOfComponentParser).flatMap {
        guard !$0.0.isEmpty else { return nil } // we must have skipped something
        return Array<TypeComponent>()
    }
}

enum TypeComponent {
    case size(CreatureSize)
    case type(String)
    case subtype(String)
    case alignment(Alignment)
}
