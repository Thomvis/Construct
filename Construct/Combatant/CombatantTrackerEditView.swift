//
//  CombatantTrackerEditView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 19/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CombatantTrackerEditView: View, Popover {

    var popoverId: AnyHashable { viewStore.state.resource.id }
    var store: Store<CombatantTrackerEditViewState, CombatantTrackerEditViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantTrackerEditViewState, CombatantTrackerEditViewAction>

    init(store: Store<CombatantTrackerEditViewState, CombatantTrackerEditViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var body: some View {
        VStack {
            Text("Add resource")
            Divider()

            VStack(spacing: 16) {
                ClearableTextField("Name", text: viewStore.binding(get: \.resource.title, send: { .resource(.title($0)) }))
                    .disableAutocorrection(true)
                Stepper(value: Binding<Int>(get: {
                    self.viewStore.state.resource.slots.count
                }, set: {
                    self.viewStore.send(.resource(.slots($0)))
                }), in: 1...10) {
                    Text(viewStore.state.resource.slots.count == 1 ? "1 use" : "\(viewStore.state.resource.slots.count) uses")
                }
            }

            Divider()
            Button(action: {
                self.viewStore.send(.onDoneTap)
            }) {
                Text("Done").bold()
            }.disabled(!viewStore.state.isValid)
        }
//        .navigationBarItems(leading: Button(action: {
//            self.store.perform(.onCancelTap)
//        }) {
//            Text("Cancel")
//        }, trailing: Button(action: {
//            self.store.perform(.onDoneTap)
//        }) {
//            Text("Done").bold()
//        }.disabled(!store.value.isValid))
    }

    func makeBody() -> AnyView {
        eraseToAnyView
    }
}

struct CombatantTrackerEditViewState: NavigationStackItemState, Equatable {
    var resource: CombatantResource

    var navigationStackItemStateId: String {
        resource.id.rawValue.uuidString
    }

    var navigationTitle: String { "" }

    var isValid: Bool {
        !resource.title.isEmpty
    }

    static let reducer: Reducer<Self, CombatantTrackerEditViewAction, Environment> = Reducer { state, action, _ in
        switch action {
        case .resource(.title(let t)):
            state.resource.title = t
        case .resource(.slots(let c)):
            if c < state.resource.slots.count {
                state.resource.slots = Array(state.resource.slots.prefix(c))
            } else if c >= state.resource.slots.count {
                state.resource.slots.append(contentsOf: Array(repeating: false, count: c - state.resource.slots.count))
            }
        case .onCancelTap, .onDoneTap: break // should be handled by parent
        }
        return .none
    }
}

enum CombatantTrackerEditViewAction: Equatable {
    case resource(ResourceAction)
    case onCancelTap
    case onDoneTap

    enum ResourceAction: Equatable {
        case title(String)
        case slots(Int)
    }
}

extension CombatantTrackerEditViewState {
    static let nullInstance = CombatantTrackerEditViewState(resource: CombatantResource.nullInstance)
}
