//
//  Sort.swift
//  Construct
//
//  Created by Thomas Visser on 01/12/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

public struct SortDescriptor<Element> {
    public let compare: (Element, Element) -> ComparisonResult

    public init(compare: @escaping (Element, Element) -> ComparisonResult) {
        self.compare = compare
    }

    public var inverse: SortDescriptor<Element> {
        return SortDescriptor { lhs, rhs in
            self.compare(rhs, lhs)
        }
    }

    public static func combine(_ descriptors: [SortDescriptor<Element>]) -> SortDescriptor<Element> {
        return SortDescriptor { lhs, rhs in
            for d in descriptors {
                if d.compare(lhs, rhs) == .orderedSame { continue }
                return d.compare(lhs, rhs)
            }
            return .orderedSame
        }
    }

    public func combined(with descriptor: SortDescriptor<Element>) -> SortDescriptor<Element> {
        SortDescriptor.combine([self, descriptor])
    }

    public func pullback<Global>(_ selector: @escaping (Global) -> Element) -> SortDescriptor<Global> {
        return SortDescriptor<Global> { lhs, rhs in
            self.compare(selector(lhs), selector(rhs))
        }
    }
}

public extension SortDescriptor {
    init<C>(_ key: KeyPath<Element, C>) where C: Comparable {
        self.compare = { lhs, rhs in
            if lhs[keyPath: key] < rhs[keyPath: key] {
                return .orderedAscending
            } else if lhs[keyPath: key] > rhs[keyPath: key] {
                return .orderedDescending
            }

            return .orderedSame
        }
    }
}

public extension Array {
    func sorted(by descriptor: SortDescriptor<Element>) -> [Element] {
        return sorted { lhs, rhs in
            descriptor.compare(lhs, rhs) == .orderedAscending
        }
    }
}
