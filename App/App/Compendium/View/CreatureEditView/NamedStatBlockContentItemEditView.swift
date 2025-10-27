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

    let store: Store<NamedStatBlockContentItemEditViewState, CreatureActionEditViewAction>

    // Note: this used to be implemented with a List, but autoSizingSheetContent stopped
    // working for it on iOS 17
    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack(spacing: 20) {
                SectionContainer(
                    accessory: Button {
                            viewStore.send(.set(\.$mode, viewStore.state.mode == .edit ? .preview : .edit), animation: .easeInOut)
                        } label: {
                            if viewStore.state.mode == .edit {
                                Label("Preview", systemImage: "text.magnifyingglass")
                            } else {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        .textCase(.none),
                    backgroundColor: Color(UIColor.systemBackground)
                ) {
                    ZStack {
                        editFields(viewStore)
                            .opacity(viewStore.state.mode == .edit ? 1.0 : 0.0)
                            .overlay {
                                // Bug: StatBlockNamedContentItemView does not appear with an animation
                                // This has to do with the AutoSizingSheetContainer, if I comment that out,
                                // the transition works
                                if viewStore.state.mode == .preview, let preview = viewStore.state.validPreview {
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

                if case .edit = viewStore.state.intent {
                    SectionContainer(
                        backgroundColor: Color(UIColor.systemBackground)
                    ) {
                        Button("Remove \(viewStore.state.itemType.localizedDisplayName)", role: .destructive) {
                            viewStore.send(.onRemoveButtonTap, animation: .default)
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
                        viewStore.send(.onDoneButtonTap)
                    } label: {
                        Text("Done").bold()
                    }
                    .disabled(viewStore.state.fields.name.isEmpty)
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
    }


    @ViewBuilder
    func editFields(_ viewStore: ViewStore<NamedStatBlockContentItemEditViewState, CreatureActionEditViewAction>) -> some View {
        VStack(spacing: 11) {
            TextField("Name", text: viewStore.$fields.name)

            Divider().padding(.trailing, -20)

            TextField("Description", text: viewStore.$fields.description, axis: .vertical)
                .lineLimit(5...)
        }

    }

}
