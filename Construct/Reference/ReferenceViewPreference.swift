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

struct ReferenceViewItemRequest: Equatable {
    let id: UUID

    private(set) var state: ReferenceItemViewState
    private(set) var stateGeneration = UUID() // when this changes, the item should update to use the current requested state

    private(set) var focusRequest = UUID() // when this changes, the item should gain focus again

    mutating func requestFocus() {
        focusRequest = UUID()
    }

    mutating func updateState(_ state: ReferenceItemViewState) {
        self.state = state
        stateGeneration = UUID()
    }
}
