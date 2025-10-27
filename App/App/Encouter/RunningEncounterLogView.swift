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
        self.viewStore = ViewStore(store, observe: \.self)
    }

    var body: some View {
        List {
            Section {
                ForEach(viewStore.state.events, id: \.id) { event in
                    RunningEncounterEventRow(encounter: self.viewStore.state.encounter.current, event: event, context: self.viewStore.state.context)
                }

                HStack {
                    Image(systemName: "shield.fill").foregroundColor(Color(UIColor.systemGray))
                    Text("Start of encounter").italic()
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
        .navigationBarItems(trailing: Group {
            if self.sheetPresentationMode != nil {
                Button(action: {
                    self.sheetPresentationMode?.dismiss()
                }) {
                    Text("Done").bold()
                }
            }
        })
    }
}
