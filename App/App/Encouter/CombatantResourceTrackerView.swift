//
//  CombatantResourceTrackerView.swift
//  Construct
//
//  Created by Thomas Visser on 19/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels

struct CombatantResourceTrackerView: View {

    @Bindable var store: StoreOf<CombatantResourceReducer>

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(store.title).font(.footnote).bold()
                Spacer()

                Menu(content: {
                    Button(action: {
                        store.send(.reset)
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }, label: {
                    HStack {
                        Text("Used \(store.slots.filter { $0 }.count) of \(store.slots.count)")
                            .foregroundColor(Color(UIColor.label))

                        Image(systemName: "ellipsis.circle")
                    }
                    .font(.footnote)

                })
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 80))], spacing: 8) {
                ForEach(Array(store.slots.enumerated()), id: \.offset) { i, _ in
                    SlotView(used: Binding(get: { store.slots[i] }, set: {
                        store.send(.slot(i, $0))
                    }))
                }
            }
        }
        .padding(.bottom, 4)
    }
}

extension CombatantResourceTrackerView {
    struct SlotView: View {
        @Binding var used: Bool

        var body: some View {
            Circle()
                .stroke(Color(UIColor.systemGray2), lineWidth: 2)
                .overlay(Group {
                    if used {
                        Circle()
                            .foregroundColor(Color(UIColor.systemGray))
                            .padding(4)
                    }
                })
                .frame(width: 33, height: 33)
                .background(Color(UIColor.systemBackground).opacity(0.001))
                .onTapGesture {
                    self.used.toggle()
                }

        }
    }
}
