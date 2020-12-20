//
//  ReferenceViewPreference.swift
//  Construct
//
//  Created by Thomas Visser on 07/12/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ReferenceViewItemKey: PreferenceKey {
    typealias Value = [RemoteReferenceViewItemRequest]

    static var defaultValue: Value { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct RemoteReferenceViewItemRequest: Equatable {
    let id: UUID
    let store: Store<ReferenceViewState.Item, ReferenceItemViewAction>
    let dismiss: () -> Void

    static func ==(lhs: RemoteReferenceViewItemRequest, rhs: RemoteReferenceViewItemRequest) -> Bool {
        lhs.id == rhs.id
    }
}

extension View {
    func referenceItem(_ store: Store<ReferenceViewState.Item?, ReferenceItemViewAction>, dismiss: @escaping () -> Void) -> some View {
        IfLetStore(store, then: { store in
            self.preference(key: ReferenceViewItemKey.self, value: [
                RemoteReferenceViewItemRequest(id: ViewStore(store).id, store: store, dismiss: dismiss)
            ])
        }, else: self)
    }
}
