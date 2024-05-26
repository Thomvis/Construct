//
//  UUID.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation

public extension UUID {
    init(fakeSeq: Int) {
        self.init(uuidString: "00000000-0000-0000-0000-" + "\(fakeSeq)".padding(toLength: 12, withPad: "0", startingAt: 0))!
    }

    static func fakeGenerator(offset: Int = 0) -> () -> UUID {
        var i = offset
        return {
            defer { i += 1 }
            return UUID(fakeSeq: i)
        }
    }
}
