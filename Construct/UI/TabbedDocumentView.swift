//
//  TabbedDocumentView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Introspect

struct TabbedDocumentView<Content>: View where Content: View {

    var items: [ContentItem]
    @Binding var selection: UUID?

    var _onDelete: ((UUID) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if items.count > 1 {
                TabBar(items: items, selection: $selection) { id in
                    if let idx = items.firstIndex(where: { $0.id == id }) {
                        if idx < items.count - 1 {
                            selection = items[idx+1].id
                        } else if idx > 0 {
                            selection = items[idx-1].id
                        } else {
                            selection = nil
                        }
                    }
                    _onDelete?(id)
                }
            }

            Divider()

            TabView(selection: $selection) {
                ForEach(items, id: \.id) { item in
                    item.view().tag(Optional.some(item.id))
                }
            }
            .introspectTabBarController { vc in
                vc.tabBar.isHidden = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.onAppear {
            selection = items.first?.id
        }
    }

    func onDelete(_ delete: @escaping (UUID) -> Void) -> Self {
        return TabbedDocumentView(items: items, selection: $selection, _onDelete: delete)
    }

    struct ContentItem {
        let id: UUID
        let label: Label<Text, Image>
        let view: () -> Content
    }

    struct TabBar: View {

        var items: [ContentItem]
        @Binding var selection: UUID?

        let onDelete: (UUID) -> Void

        var body: some View {
            HStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    TabBarItemView(label: item.label, selected: Binding(get: {
                        item.id == selection
                    }, set: {
                        if $0 {
                            selection = item.id
                        }
                    }), onDelete: {
                        onDelete(item.id)
                    })
                    // if we set both onDrag and gesture, the drag is never called
//                    .if(item.id == selection) {
//                        $0.onDrag {
//                            NSItemProvider()
//                        }
//                    }
                    .if(item.id != selection) {
                        $0.gesture(LongPressGesture().onChanged { _ in
                            selection = item.id
                        })
                    }
                    // add divider between two unselected tabs
                    .if(addDivider(after: item.id)) {
                        $0.overlay(HStack {
                            Spacer()
                            Divider()
                        })
                    }
                }
            }
        }

        func addDivider(after id: UUID) -> Bool {
            guard selection != id,
                  let idx = items.firstIndex(where: { $0.id == id }),
                  idx < items.count-1,
                  items[idx+1].id != selection else { return false }
            return true
        }
    }

    struct TabBarItemView: View {
        let label: Label<Text, Image>
        @Binding var selected: Bool

        let onDelete: () -> Void

        var body: some View {
            label.labelStyle(LabelStyle(selected: selected))
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .if(selected) {
                    $0.overlay(
                        Button(action: {
                            onDelete()
                        }) {
                            Image(systemName: "xmark.square.fill")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    )
                }
                .padding(10)
                .frame(minHeight: 32)
                .background(Color(selected ? UIColor.systemGray6 : UIColor.systemGray5))
                .accentColor(Color(UIColor.gray))
        }

        struct LabelStyle: SwiftUI.LabelStyle {
            let selected: Bool

            func makeBody(configuration: Configuration) -> some View {
                HStack {
                    configuration.icon
                        .foregroundColor(Color(UIColor.gray))

                    configuration.title
                        .lineLimit(1)
                        .if(selected) { $0.font(Font.footnote.weight(.bold)) }
                        .foregroundColor(Color(selected ? UIColor.label : UIColor.gray))
                }
            }
        }
    }
}
