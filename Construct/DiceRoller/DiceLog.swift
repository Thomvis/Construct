//
//  DiceLog.swift
//  Construct
//
//  Created by Thomas Visser on 29/12/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

struct DiceLogEntry: Hashable {
    let id: Tagged<DiceLogEntry, UUID>
    let roll: Roll
    let rolledBy: RollAuthor
    var results: [Result]

    // Future-proofing
    enum RollAuthor: Hashable {
        case DM
    }

    enum Roll: Hashable {
        case custom(DiceExpression)
    }

    struct Result: Hashable {
        let id: Tagged<Result, UUID>
        let type: ResultType

        let first: RolledDiceExpression
        let second: RolledDiceExpression?

        var effectiveResult: RolledDiceExpression {
            guard let second = second else { return first }

            switch type {
            case .disadvantage:
                if second.total < first.total {
                    return second
                }
            case .advantage:
                if second.total > first.total {
                    return second
                }
            default: break
            }

            return first
        }

        enum ResultType: Hashable {
            case normal
            case disadvantage
            case advantage
        }
    }
}
