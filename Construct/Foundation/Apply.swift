//
//  Apply.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 23/02/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

func apply<T>(_ thing: T, _ f: (inout T) -> Void) -> T {
    var res = thing
    f(&res)
    return res
}

@discardableResult
func apply<T>(_ thing: inout T, _ f: (inout T) -> Void) -> T {
    f(&thing)
    return thing
}
