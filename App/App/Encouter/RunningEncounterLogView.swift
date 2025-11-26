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

    let store: Store<RunningEncounterLogViewState, RunningEncounterLogViewAction>

    var body: some View {
        List {
            Section {
                ForEach(store.events, id: \.id) { event in
                    RunningEncounterEventRow(encounter: store.encounter.current, event: event, context: store.context)
                }

                HStack {
                    Image(systemName: "shield.fill").foregroundColor(Color(UIColor.systemGray))
                    Text("Start of encounter").italic()
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
        .navigationBarItems(trailing: Group {
            if sheetPresentationMode != nil {
                Button(action: {
                    sheetPresentationMode?.dismiss()
                }) {
                    Text("Done").bold()
                }
            }
        })
    }
}
