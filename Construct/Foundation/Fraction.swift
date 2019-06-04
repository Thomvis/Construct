//
//  Fraction.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 24/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

struct Fraction: Codable, Hashable {
    let numenator: Int
    let denominator: Int

    var double: Double {
        return Double(numenator) / Double(denominator)
    }
}

extension Fraction: Comparable {
    static func < (lhs: Fraction, rhs: Fraction) -> Bool {
        lhs.double < rhs.double
    }
}

extension Fraction {
    init(integer: Int) {
        self.numenator = integer
        self.denominator = 1
    }
}

extension Fraction: RawRepresentable {
    init?(rawValue fraction: String) {
        let components = fraction.split(separator: "/")
        if components.count == 2, let n = Int(components[0]), let d = Int(components[1]) {
            self.numenator = n
            self.denominator = d
        } else if let parsed = Int(fraction) {
            self.numenator = parsed
            self.denominator = 1
        } else {
            return nil
        }
    }

    var rawValue: String {
        guard denominator != 1 else { return "\(numenator)" }
        return "\(numenator)/\(denominator)"
    }
}

extension Fraction {
    static let oneEighth = Fraction(numenator: 1, denominator: 8)
    static let oneQuarter = Fraction(numenator: 1, denominator: 4)
    static let half = Fraction(numenator: 1, denominator: 2)
}
