//
//  Helpers.swift
//  UnitTests
//
//  Created by Thomas Visser on 20/07/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

extension UUID {
    init(fakeSeq: Int) {
        self.init(uuidString: "00000000-0000-0000-0000-" + "\(fakeSeq)".padding(toLength: 12, withPad: "0", startingAt: 0))!
    }

    static func fakeGenerator() -> () -> UUID {
        var i = 0
        return {
            defer { i += 1 }
            return UUID(fakeSeq: i)
        }
    }
}
