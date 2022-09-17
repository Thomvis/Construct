//
//  PropagateSize.swift
//  
//
//  Created by Thomas Visser on 17/09/2022.
//

import Foundation
import SwiftUI

public struct PropagatedSizeKey<ID: Hashable>: PreferenceKey {
    public typealias Value = [ID: CGSize]

    public static var defaultValue: [ID: CGSize] { [:] }
    public static func reduce(value: inout [ID:CGSize], nextValue: () -> [ID:CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct PropagateSize<V: View, ID: Hashable>: View {
    let content: V
    let id: ID

    public init(content: V, id: ID) {
        self.content = content
        self.id = id
    }

    public var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: PropagatedSizeKey<ID>.self, value: [self.id: proxy.size])
        })
    }
}
