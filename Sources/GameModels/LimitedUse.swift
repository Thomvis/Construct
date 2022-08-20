//
//  LimitedUse.swift
//  Construct
//
//  Created by Thomas Visser on 22/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

public struct LimitedUse: Codable, Hashable {
    public let amount: Int
    public let recharge: Recharge?

    public init(amount: Int, recharge: Recharge?) {
        self.amount = amount
        self.recharge = recharge
    }

    public enum Recharge: Codable, Hashable {
        case rest(short: Bool, long: Bool)
        case day
        case turnStart(Set<Int>) // with a d6 roll
    }
}

extension LimitedUse {
    public var displayString: String {
        let amountString = String(AttributedString("^[\(amount) time](inflect: true)").characters)

        switch recharge {
        case nil: return amountString
        case .rest(short: false, long: false): return amountString
        case .rest(short: false, long: true):
            if amount == 1 {
                return "Recharges after a Long Rest"
            }
            return "\(amountString) per Long Rest"
        case .rest(short: true, long: false):
            if amount == 1 {
                return "Recharges after a Short Rest"
            }
            return "\(amountString) per Short Rest"
        case .rest(short: true, long: true):
            if amount == 1 {
                return "Recharges after a Short or Long Rest"
            }
            return "\(amountString) per Short or Long Rest"
        case .day:
            return "\(amount)/Day"
        case .turnStart(let s):
            let numbers = s.sorted().map { "\($0)" }.joined(separator: "-")
            if amount == 1 {
                return "Recharge \(numbers)"
            } else {
                return "\(amountString), Recharge \(numbers)"
            }
        }
    }
}
