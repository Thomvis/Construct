//
//  CancellableBag.swift
//  Construct
//
//  Created by Thomas Visser on 23/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine

final class CancellableBag: Cancellable {

    var isCancelled = false
    var cancellables: [AnyCancellable] = []

    func add(_ cancellable: AnyCancellable) {
        if !isCancelled {
            cancellables.append(cancellable)
        }
    }

    func cancel() {
        isCancelled = true
        cancellables = []
    }

}

extension CancellableBag: Collection {
    func index(after i: Int) -> Int {
        cancellables.index(after: i)
    }

    subscript(position: Int) -> AnyCancellable { cancellables[position] }

    var startIndex: Int { cancellables.startIndex }
    var endIndex: Int { cancellables.endIndex }

    typealias Index = Int
}

extension CancellableBag: RangeReplaceableCollection {
    func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: __owned C) where C : Collection, C.Element == AnyCancellable {
        cancellables.replaceSubrange(subrange, with: newElements)
    }
}
