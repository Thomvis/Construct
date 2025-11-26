//
//  NumberEntryPopover.swift
//  Construct
//
//  Created by Thomas Visser on 27/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews

// A popover that allows for number entry, either by hand or by simulated dice rolls
struct NumberEntryPopover: Popover, View {

    var popoverId: AnyHashable { "NumberEntryPopover" }
    var store: StoreOf<NumberEntryFeature>
    let onOutcomeSelected: (Int) -> Void

    init(store: StoreOf<NumberEntryFeature>, onOutcomeSelected: @escaping (Int) -> Void) {
        self.store = store
        self.onOutcomeSelected = onOutcomeSelected
    }

    var body: some View {
        VStack {
            NumberEntryView(store: self.store)
            Divider()
            Button(action: {
                self.onOutcomeSelected(store.value ?? 0)
            }) {
                Text("Use")
            }.disabled(store.value == nil)
        }
    }

    func makeBody() -> AnyView {
        return AnyView(self)
    }
}
