//
//  RunningEncounterLogView.swift
//  Construct
//
//  Created by Thomas Visser on 14/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct RunningEncounterLogView: View {
    @SwiftUI.Environment(\.sheetPresentationMode) var sheetPresentationMode: SheetPresentationMode?

    var store: Store<RunningEncounterLogViewState, Void>
    @ObservedObject var viewStore: ViewStore<RunningEncounterLogViewState, Void>

    init(store: Store<RunningEncounterLogViewState, Void>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var body: some View {
        List {
            Section {
                ForEach(viewStore.state.events, id: \.id) { event in
                    RunningEncounterEventRow(encounter: self.viewStore.state.encounter.current, event: event, context: self.viewStore.state.context)
                }

                HStack {
                    Image(systemName: "shield.fill").foregroundColor(Color.systemGray)
                    Text("Start of encounter").italic()
                }
            }
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #endif
        .navigationTitle(Text(viewStore.state.navigationTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
//            if self.sheetPresentationMode != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        self.sheetPresentationMode?.dismiss()
                    }) {
                        Text("Done").bold()
                    }
                }
//            }
        }
    }
}
