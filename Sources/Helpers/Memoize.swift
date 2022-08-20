//
//  Memoize.swift
//  Construct
//
//  Created by Thomas Visser on 16/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

/// Returns a modified closure that emits the latest non-nil value
/// if the original closure would return nil
public func replayNonNil<A, B>(_ f: @escaping (A) -> B?) -> (A) -> B? {
    var memo: B? = nil
    return {
        if let res = f($0) {
            memo = res
            return res
        }
        return memo
    }
}
