//
//  Zip.swift
//  Construct
//
//  Created by Thomas Visser on 14/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

public func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a = a, let b = b else { return nil }
    return (a, b)
}
