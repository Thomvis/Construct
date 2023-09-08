//
//  CompendiumDocumentsFeature.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import SharedViews
import ComposableArchitecture

struct CompendiumDocumentsFeature: ReducerProtocol {
    struct State: Equatable {
        
    }

    enum Action {

    }

    var body: some ReducerProtocol<State, Action> {
        Reduce { _, _ in
            .none
        }
    }
}

struct CompendiumDocumentsView: View {

    @State var sheet = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionContainer(
                    title: "Realm name",
                    accessory: Menu(content: {
                        Button(action: {

                        }, label: {
                            Label("Add document", systemImage: "plus.circle")
                        })

                        Button(role: .destructive, action: {}, label: {
                            Label("Remove empty realm", systemImage: "trash")
                        })
                        .disabled(true)
                    }, label: {
                        Image(systemName: "ellipsis.circle")
                    })
                ) {
                    VStack {

                        NavigationRowButton {
                            self.sheet = true
                        } label: {
                            HStack {
                                Text("Tome of Beasts")
                                Spacer()
                                Text("tob")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 35)


                        Divider()

                        NavigationRowButton {

                        } label: {
                            HStack {
                                Text("Tome of Beasts 2")
                                Spacer()
                                Text("tob2")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 35)
                    }
                }

                SectionContainer(
                    title: "Some other realm"
                ) {
                    Text("No documents").italic().frame(maxWidth: .infinity, minHeight: 35)
                }
            }
            .padding()
        }
        .sheet(isPresented: $sheet, content: {
            AutoSizingSheetContainer {
                SheetNavigationContainer {
                    CompendiumDocumentEditView()
                        .navigationTitle("Edit")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .interactiveDismissDisabled()
        })
        .safeAreaInset(edge: .bottom) {
            RoundedButtonToolbar {
                Button(action: {

                }) {
                    Label("Add realm", systemImage: "plus.circle")
                }
            }
        }
    }
}

struct CompendiumDocumentEditView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionContainer {
                    VStack {
                        TextFieldWithSlug(
                            title: "",
                            text: Binding.constant("Tome of Beasts"),
                            slug: Binding.constant("tob"),
                            configuration: .init(
                                textForegroundColor: Color(UIColor.label),
                                slugForegroundColor: Color(UIColor.secondaryLabel)
                            )
                        )
                        .padding(.trailing, 10) // to align with the picker field

                        Divider()

                        MenuPickerField(
                            title: "Realm",
                            selection: Binding.constant(Optional<String>.none)
                        ) {

                        }
                    }
                }

                SectionContainer(title: "Contents") {
                    VStack(alignment: .leading) {
                        Text("Document contains 1 item(s)")
                            .foregroundStyle(Color.secondary)
                            .frame(minHeight: 35)

                        Divider()

                        DisclosureGroup(content: {
                            SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
                                VStack {
                                    MenuPickerField(
                                        title: "Move to",
                                        selection: Binding.constant(Optional<String>.none)
                                    ) {

                                    }

                                    Button(action: { }, label: {
                                        Text("Move")
                                    })
                                }
                            }
                        }, label: {
                            Label("Move", systemImage: "doc").tint(Color.secondary)
                                .symbolVariant(.circle.fill)
                                .imageScale(.large)
                                .symbolRenderingMode(.hierarchical)
                        })
                    }
                }

                SectionContainer {
                    VStack {
                        Menu {
                            Text("Do you want to remove the document and its content?").font(.footnote)

                            Divider()

                            Button(role: .destructive) {

                            } label: {
                                Label("Confirm", systemImage: "trash")
                            }

                        } label: {
                            Button(role: .destructive, action: { }) {
                                Label("Remove document & contents", systemImage: "trash")
                                Spacer()
                            }
                            .symbolVariant(.circle.fill)
                            .imageScale(.large)
                        }
                        .frame(minHeight: 35)
                    }
                }
                .symbolRenderingMode(.hierarchical)
            }
            .padding()
            .autoSizingSheetContent(constant: 100)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}, label: {
                    Text("Done").bold()
                })
            }

            ToolbarItem(placement: .navigation) {
                Button("Cancel", role: .destructive) {

                }
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
struct CompendiumDocumentsPreview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CompendiumDocumentsView()
                .navigationTitle("Realms & documents")
        }
    }
}
#endif
