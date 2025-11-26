//
//  CampaignBrowseView.swift
//  Construct
//
//  Created by Thomas Visser on 11/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture
import Helpers
import SharedViews
import GameModels

struct CampaignBrowseView: View {
    @SwiftUI.Environment(\.sheetPresentationMode) var sheetPresentationMode: SheetPresentationMode?

    @Bindable var store: StoreOf<CampaignBrowseViewFeature>

    var body: some View {
        List {
            if let items = store.sortedItems {
                ForEach(items, id: \.id) { item in
                    self.itemView(item).disabled(store.state.isItemDisabled(item))
                }
                .onDelete(perform: self.onDelete)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .safeAreaInset(edge: .bottom) {
            RoundedButtonToolbar {
                if !store.state.isMoveMode {
                    Button(action: {
                        store.send(.setSheet(.nodeEdit(CampaignBrowseViewFeature.State.NodeEditState(name: "", node: nil))))
                    }) {
                        Label("New group", systemImage: "folder")
                    }

                    Button(action: {
                        store.send(.setSheet(.nodeEdit(CampaignBrowseViewFeature.State.NodeEditState(name: "", contentType: .encounter, node: nil))))
                    }) {
                        Label("New encounter", systemImage: "shield")
                    }
                } else if let movingNodesDescription = store.state.movingNodesDescription {
                    Button(action: {
                        store.send(.didTapConfirmMoveButton)
                    }) {
                        Label("Move \(movingNodesDescription) here", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(store.state.isMoveOrigin)
                }
            }
            .padding(8)
        }
        .navigationBarTitle(store.state.navigationBarTitle, displayMode: .inline)
        .toolbar {
            if store.state.showSettingsButton {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        store.send(.setSheet(.settings))
                    }) {
                        Text("Settings")
                    }
                }
            }

            if store.state.isMoveMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        self.sheetPresentationMode?.dismiss()
                    }) {
                        Text("Cancel")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.send(.setSheet(.nodeEdit(CampaignBrowseViewFeature.State.NodeEditState(name: "", node: nil))))
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
        .navigationDestination(
            store: store.scope(state: \.$destination, action: \.destination)
        ) { destinationStore in
            switch destinationStore.case {
            case let .campaignBrowse(store):
                CampaignBrowseView(store: store)
            case let .encounter(store):
                EncounterDetailView(store: store)
            }
        }
        .onAppear {
            store.send(.items(.startLoading))
        }
        .modifier(Sheets(store: store))
    }

    struct Sheets: ViewModifier {
        let store: StoreOf<CampaignBrowseViewFeature>

        func body(content: Content) -> some View {
            content
                .sheet(
                    store: store.scope(state: \.$sheet.settings, action: \.sheet.settings)
                ) { _ in
                    SettingsContainerView()
                }
                .sheet(
                    store: store.scope(state: \.$sheet.nodeEdit, action: \.sheet.nodeEdit)
                ) { store in
                    SheetNavigationContainer {
                        NodeEditView(
                            store: store,
                            onDoneTap: { state, node, title in
                                self.store.send(.didTapNodeEditDone(state, node, title))
                            }
                        )
                    }
                }
                .sheet(
                    store: store.scope(state: \.$sheet.move, action: \.sheet.move)
                ) { store in
                    SheetNavigationContainer {
                        CampaignBrowseView(store: store)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
    }

    func itemView(_ item: CampaignNode) -> some View {
        func content() -> some View {
            HStack {
                Image(systemName: item.iconName).frame(width: 30)
                Text(item.title)
                Spacer()
            }
        }

        func menu() -> some View {
            Group {
                Button(action: {
                    store.send(.setSheet(.move(CampaignBrowseViewFeature.State(node: .root, mode: .move([item]), items: .initial, showSettingsButton: false))))
                }) {
                    Text("Move")
                    Image(systemName: "folder")
                }

                Button(action: {
                    store.send(.remove(item))
                }) {
                    Text("Remove")
                    Image(systemName: "trash")
                }

                Button(action: {
                    store.send(.setSheet(.nodeEdit(CampaignBrowseViewFeature.State.NodeEditState(name: item.title, contentType: item.contents?.type, node: item))))
                }) {
                    Text("Rename")
                    Image(systemName: "plus.square.on.square")
                }
            }
        }

        return Group {
            if item.special != nil {
                self.navigationLink(for: item) {
                    content().font(Font.body.weight(.semibold))
                }
            } else if store.state.isMoveMode {
                if store.state.isBeingMoved(item) {
                    content().foregroundColor(Color(UIColor.secondaryLabel))
                } else {
                    self.navigationLink(for: item) {
                        content()
                    }
                }
            } else {
                self.navigationLink(for: item) {
                    content().contextMenu { menu() }
                }
            }
        }
        .deleteDisabled(store.state.isMoveMode || item.special != nil)
    }

    func navigationLink<Label>(for item: CampaignNode, @ViewBuilder label: @escaping () -> Label) -> some View where Label: View {
        NavigationRowButton {
            @Dependency(\.database) var database
            @Dependency(\.crashReporter) var crashReporter
            @Dependency(\.preferences) var preferencesClient
            // FIXME: move logic to reducer

            let nextScreen: CampaignBrowseViewFeature.Destination.State
            if let contents = item.contents {
                switch contents.type {
                case .encounter:
                    if let encounter: Encounter = try? database.keyValueStore.get(
                        contents.key,
                        crashReporter: crashReporter
                    ) {
                        let runningEncounter: RunningEncounter? = encounter.runningEncounterKey
                            .flatMap { try? database.keyValueStore.get($0, crashReporter: crashReporter) }
                        let detailState = EncounterDetailFeature.State(
                            building: encounter,
                            running: runningEncounter,
                            isMechMuseEnabled: preferencesClient.get().mechMuse.enabled
                        )
                        nextScreen = .encounter(detailState)
                    } else {
                        nextScreen = .encounter(EncounterDetailFeature.State.nullInstance)
                    }
                case .other:
                    assertionFailure("Other item type is not supported")
                    nextScreen = .encounter(EncounterDetailFeature.State.nullInstance)
                }
            } else {
                // group
                nextScreen = .campaignBrowse(CampaignBrowseViewFeature.State(node: item, mode: store.mode, items: .initial, showSettingsButton: false))
            }

            store.send(.setDestination(nextScreen))
        } label: {
            label()
        }
    }

    func onDelete(_ indices: IndexSet) {
        guard let items = store.sortedItems else { return }
        for i in indices {
            store.send(.remove(items[i]))
        }
    }

}

struct NodeEditView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let store: StoreOf<CampaignBrowseViewFeature.NodeEdit>
    let onDoneTap: (CampaignBrowseViewFeature.State.NodeEditState, CampaignNode?, String) -> Void

    @State var didFocusOnField = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: viewStore.state.contentType.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200.0, height: 200.0)

                    HStack {
                        ClearableTextField("Name", text: viewStore.$name, onCommit: {
                            saveAndDismissIfValid(viewStore)
                        })
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .introspectTextField { textField in
                            if !textField.isFirstResponder, !didFocusOnField {
                                textField.becomeFirstResponder()
                                didFocusOnField = true
                            }
                        }
                        .submitLabel(.done)
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground).cornerRadius(4))
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground).opacity(0.90).edgesIgnoringSafeArea(.all))
            .navigationBarTitle("\(viewStore.state.node != nil ? "Rename" : "Add") \(viewStore.state.contentType.displayName)", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                },
                trailing: Button(action: {
                    saveAndDismissIfValid(viewStore)
                }) {
                    Text("Done").bold()
                }.disabled(viewStore.state.name.isEmpty)
            )
        }
    }

    func saveAndDismissIfValid(_ viewStore: ViewStore<CampaignBrowseViewFeature.State.NodeEditState, CampaignBrowseViewFeature.NodeEdit.Action>) {
        guard !viewStore.state.name.isEmpty else { return }

        self.onDoneTap(viewStore.state, viewStore.state.node, viewStore.state.name)
        self.presentationMode.wrappedValue.dismiss()
    }
}

extension CampaignNode {
    var iconName: String {
        (contents?.type).iconName
    }
}

extension Optional where Wrapped == CampaignNode.Contents.ContentType {
    var iconName: String {
        switch self {
        case nil: return "folder"
        case .encounter?: return "shield"
        case .other?: return "doc"
        }
    }

    var displayName: String {
        switch self {
        case nil: return "group"
        case .encounter?: return "encounter"
        case .other?: return "other"
        }
    }
}
