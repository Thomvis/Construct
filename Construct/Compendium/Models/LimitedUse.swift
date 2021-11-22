//
//  LimitedUse.swift
//  Construct
//
//  Created by Thomas Visser on 22/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

struct LimitedUse: Codable, Hashable {
    let amount: Int
    let recharge: Recharge?

    enum Recharge: Codable, Hashable {
        case rest(short: Bool, long: Bool)
        case day
        case turnStart(Set<Int>) // with a d6 roll
    }
}
