//
//  Invocations.swift
//  Construct
//
//  Created by Thomas Visser on 23/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import DiceRollerInvocation
import URLRouting

enum AppInvocation {
    case diceRoller(DiceRollerInvocation)
}

let appInvocationRouter = OneOf {
    Route(.case(AppInvocation.diceRoller)) {
        Host("roll.construct5e.app")
        diceRollerInvocationRouter
    }
}
