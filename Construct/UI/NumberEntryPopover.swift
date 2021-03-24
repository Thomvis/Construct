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

// A popover that allows for number entry, either by hand or by simulated dice rolls
struct NumberEntryPopover: Popover, View {

    var popoverId: AnyHashable { "NumberEntryPopover" }
    var store: Store<NumberEntryViewState, NumberEntryViewAction>
    let onOutcomeSelected: (Int) -> Void

    init(store: Store<NumberEntryViewState, NumberEntryViewAction>, onOutcomeSelected: @escaping (Int) -> Void) {
        self.store = store
        self.onOutcomeSelected = onOutcomeSelected
    }

    var body: some View {
        WithViewStore(store.scope(state: State.init)) { viewStore in
            VStack {
                NumberEntryView(store: self.store)
                Divider()
                Button(action: {
                    self.onOutcomeSelected(viewStore.state.outcome ?? 0)
                }) {
                    Text("Use")
                }.disabled(viewStore.state.outcome == nil)
            }
        }
    }

    func makeBody() -> AnyView {
        return AnyView(self)
    }

    struct State: Equatable {
        let outcome: Int?

        init(_ state: NumberEntryViewState) {
            self.outcome = state.value
        }
    }
}
