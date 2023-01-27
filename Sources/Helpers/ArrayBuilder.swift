//
//  ArrayBuilder.swift
//  
//
//  Created by Thomas Visser on 27/12/2022.
//

import Foundation

@resultBuilder
public struct ArrayBuilder<Element> {
    public static func buildPartialBlock(first: Element) -> [Element] {
        [first]
    }

    public static func buildPartialBlock(first: Element?) -> [Element] {
        first.map { [$0] } ?? []
    }

    public static func buildPartialBlock(first: [Element]) -> [Element] {
        first
    }

    public static func buildPartialBlock(accumulated: [Element], next: Element) -> [Element] {
        accumulated + [next]
    }

    public static func buildPartialBlock(accumulated: [Element], next: [Element]) -> [Element] {
        accumulated + next
    }

    public static func buildIf(_ element: [Element]?) -> [Element] {
        element ?? []
    }
}

public extension Array {
    init(@ArrayBuilder<Element> builder: () -> [Element]) {
        self = builder()
    }
}
