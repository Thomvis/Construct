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
    let id: TabbedDocumentViewContentItem.Id

    private(set) var state: ReferenceItem.State
    private(set) var stateGeneration = UUID() // when this changes, the item should update to use the current requested state

    private(set) var focusRequest = UUID() // when this changes, the item should gain focus again

    /**
     If true, the request is not tracked after the item has been created.
     Requesting focus or updating the state will not work.
     If the request is no longer active, the item will not be removed.
     */
    let oneOff: Bool

    mutating func requestFocus() {
        focusRequest = UUID()
    }

    mutating func updateState(_ state: ReferenceItem.State) {
        self.state = state
        stateGeneration = UUID()
    }
}
