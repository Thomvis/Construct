//
//  Apply.swift
//  Construct
//
//  Created by Thomas Visser on 23/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

public func apply<T>(_ thing: T, _ f: (inout T) throws -> Void) rethrows -> T {
    var res = thing
    try f(&res)
    return res
}

public func apply<T, R>(_ thing: inout T, _ f: (inout T) throws -> R) rethrows -> R {
    return try f(&thing)
}

public func apply<T>(_ thing: T, _ f: (inout T) async throws -> Void) async rethrows -> T {
    var res = thing
    try await f(&res)
    return res
}

public func apply<T, R>(_ thing: inout T, _ f: (inout T) async throws -> R) async rethrows -> R {
    return try await f(&thing)
}
