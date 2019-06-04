//
//  SharedLiterals.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

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
