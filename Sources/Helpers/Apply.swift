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

@discardableResult
public func apply<T>(_ thing: inout T, _ f: (inout T) throws -> Void) rethrows -> T {
    try f(&thing)
    return thing
}

public func apply<T>(_ thing: T, _ f: (inout T) async throws -> Void) async rethrows -> T {
    var res = thing
    try await f(&res)
    return res
}

@discardableResult
public func apply<T>(_ thing: inout T, _ f: (inout T) async throws -> Void) async rethrows -> T {
    try await f(&thing)
    return thing
}
