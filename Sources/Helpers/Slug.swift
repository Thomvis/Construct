//
//  Slug.swift
//
//
//  Created by Thomas Visser on 01/12/2023.
//

import Foundation

public func slug(_ string: String) -> String {
    let components = string.split(separator: " ").compactMap { $0.first.map(String.init)?.lowercased() }

    if components.count == 1 {
        return string.prefix(3).lowercased()
    }

    return components.joined()
}
