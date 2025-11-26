//
//  NamedStatBlockContentItemEditView.swift
//  Construct
//
//  Created by Thomas Visser on 04/11/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct NamedStatBlockContentItemEditView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @Bindable var store: StoreOf<NamedStatBlockContentItemEditFeature>

    // Note: this used to be implemented with a List, but autoSizingSheetContent stopped
    // working for it on iOS 17
    var body: some View {
        VStack(spacing: 20) {
            SectionContainer(
                accessory: Button {
                    store.send(.set(\.mode, store.mode == .edit ? .preview : .edit), animation: .easeInOut)
                } label: {
                    if store.state.mode == .edit {
                        Label("Preview", systemImage: "text.magnifyingglass")
                    } else {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                .textCase(.none),
                backgroundColor: Color(UIColor.systemBackground)
            ) {
                ZStack {
                    editFields($store)
                        .opacity(store.mode == .edit ? 1.0 : 0.0)
                        .overlay {
                            // Bug: StatBlockNamedContentItemView does not appear with an animation
                            // This has to do with the AutoSizingSheetContainer, if I comment that out,
                            // the transition works
                            if store.mode == .preview, let preview = store.validPreview {
                                StatBlockNamedContentItemView(item: preview)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text("Links are not tappable in preview")
                                            .foregroundColor(Color.secondary)
                                            .font(.footnote)
                                    }
                            }
                        }
                }
                .padding(2)
            }

            if case .edit = store.intent {
                SectionContainer(
                    backgroundColor: Color(UIColor.systemBackground)
                ) {
                    Button("Remove \(store.itemType.localizedDisplayName)", role: .destructive) {
                        store.send(.onRemoveButtonTap, animation: .default)
                    }
                    .padding(2)
                    .frame(minHeight: 35)
                }
            }
        }
        .padding()
        .autoSizingSheetContent(constant: 40) // 40 for the navigationbar
        .environment(\.openURL, OpenURLAction { _ in
            // this makes the links in the preview do nothing
            return .handled
        })
        .frame(maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    store.send(.onDoneButtonTap)
                } label: {
                    Text("Done").bold()
                }
                .disabled(store.fields.name.isEmpty)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel")
                }
            }
        }
    }


    @ViewBuilder
    func editFields(_ store: Bindable<StoreOf<NamedStatBlockContentItemEditFeature>>) -> some View {
        VStack(spacing: 11) {
            TextField("Name", text: store.fields.name)

            Divider().padding(.trailing, -20)

            TextField("Description", text: store.fields.description, axis: .vertical)
                .lineLimit(5...)
        }

    }

}
