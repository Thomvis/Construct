//
//  CombatantResourceTrackerView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 19/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CombatantResourceTrackerView: View {

    var store: Store<CombatantResource, CombatantResourceAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                HStack {
                    Text(viewStore.state.title).font(.footnote).bold()
                    Spacer()

                    Menu(content: {
                        Button(action: {
                            viewStore.send(.reset)
                        }) {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                    }, label: {
                        HStack {
                            Text("Used \(viewStore.state.slots.filter { $0 }.count) of \(viewStore.state.slots.count)")
                                .foregroundColor(Color(UIColor.label))

                            Image(systemName: "ellipsis.circle")
                        }
                        .font(.footnote)

                    })
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 80))], spacing: 8) {
                    ForEach(0..<viewStore.state.slots.count, id: \.self) { i in
                        SlotView(used: Binding(get: { viewStore.state.slots[i] }, set: {
                            viewStore.send(.slot(i, $0))
                        }))
                    }
                }
            }
            .padding(.bottom, 4)
        }
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

extension Int: Identifiable {
    public var id: Int { self }
}
