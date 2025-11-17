//
//  UUID.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation
import ComposableArchitecture

public extension UUID {
    init(fakeSeq: Int) {
        self.init(uuidString: "00000000-0000-0000-0000-" + "\(fakeSeq)".padding(toLength: 12, withPad: "0", startingAt: 0))!
    }
}

private final class FakeUUIDGenerator: @unchecked Sendable {
    private let lock = NSLock()
    private var sequence = 0

    public init(offset: Int = 0) {
        self.sequence = offset
    }

    func callAsFunction() -> UUID {
        self.lock.lock()
        defer {
            self.sequence += 1
            self.lock.unlock()
        }
        return UUID(fakeSeq: sequence)
    }
}

public extension UUIDGenerator {
    static func fake(offset: Int = 0) -> Self {
        let generator = FakeUUIDGenerator(offset: offset)
        return Self { generator() }
    }
}
