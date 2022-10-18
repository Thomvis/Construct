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
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.sheetPresentationMode) var sheetPresentationMode: SheetPresentationMode?

    var store: Store<CampaignBrowseViewState, CampaignBrowseViewAction>
    @ObservedObject var viewStore: ViewStore<CampaignBrowseViewState, CampaignBrowseViewAction>

    init(store: Store<CampaignBrowseViewState, CampaignBrowseViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if let movingNodesDescription = viewStore.state.movingNodesDescription {
                    Button(action: {
                        self.viewStore.send(.didTapConfirmMoveButton)
                    }) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down").frame(width: 30)
                            Text("Move \(movingNodesDescription) here")
                        }
                    }
                    .disabled(viewStore.state.isMoveOrigin)
                    .font(.footnote)
                    .padding(12)
                    .frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemBackground))
                }

                List {
                    viewStore.state.sortedItems.map { items in
                        ForEach(items, id: \.id) { item in
                            self.itemView(item).disabled(viewStore.state.isItemDisabled(item))
                        }.onDelete(perform:self.onDelete)
                    }
                }.listStyle(InsetGroupedListStyle())
            }

            RoundedButtonToolbar {
                Button(action: {
                    self.viewStore.send(.sheet(.nodeEdit(CampaignBrowseViewState.NodeEditState(name: "", node: nil))))
                }) {
                    Label("New group", systemImage: "folder")
                }

                if !viewStore.state.isMoveMode {
                    Button(action: {
                        self.viewStore.send(.sheet(.nodeEdit(CampaignBrowseViewState.NodeEditState(name: "", contentType: .encounter, node: nil))))
                    }) {
                        Label("New encounter", systemImage: "shield")
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
            .ignoresSafeArea(.keyboard, edges: .all)
        }
        .sheet(item: viewStore.binding(get: \.sheet) { _ in .sheet(nil) }, content: self.sheetView)
        .navigationBarTitle(viewStore.state.navigationBarTitle, displayMode: .inline)
        .background(Group {
            if viewStore.state.showSettingsButton {
                EmptyView()
                    .navigationBarItems(leading: Button(action: {
                        self.viewStore.send(.sheet(.settings))
                    }) {
                        Text("About")
                    })
            } else if viewStore.state.isMoveMode {
                EmptyView()
                    .navigationBarItems(trailing: Button(action: {
                        self.sheetPresentationMode?.dismiss()
                    }) {
                        Text("Cancel")
                    })
            }
        })
        .onAppear {
            self.viewStore.send(.items(.startLoading))
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
                    self.viewStore.send(.sheet(.move(CampaignBrowseViewState(node: .root, mode: .move([item]), items: .initial, showSettingsButton: false, sheet: nil))))
                }) {
                    Text("Move")
                    Image(systemName: "folder")
                }

                Button(action: {
                    self.viewStore.send(.remove(item))
                }) {
                    Text("Remove")
                    Image(systemName: "trash")
                }

                Button(action: {
                    self.viewStore.send(.sheet(.nodeEdit(CampaignBrowseViewState.NodeEditState(name: item.title, contentType: item.contents?.type, node: item))))
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
            } else if self.viewStore.state.isMoveMode {
                if self.viewStore.state.isBeingMoved(item) {
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
        .deleteDisabled(self.viewStore.state.isMoveMode || item.special != nil)
    }

    func navigationLink<Label>(for item: CampaignNode, @ViewBuilder label: @escaping () -> Label) -> some View where Label: View {
        guard let contents = item.contents else { // group
            return StateDrivenNavigationLink(
                store: store,
                state: /CampaignBrowseViewState.NextScreen.campaignBrowse,
                action: /CampaignBrowseViewAction.NextScreenAction.campaignBrowse,
                isActive: { $0.node == item },
                initialState: CampaignBrowseViewState(node: item, mode: self.viewStore.state.mode, items: .initial, showSettingsButton: false),
                destination: CampaignBrowseView.init,
                label: label
            ).eraseToAnyView
        }

        switch contents.type {
        case .encounter:
            return StateDrivenNavigationLink(
                store: store,
                state: /CampaignBrowseViewState.NextScreen.encounter,
                action: /CampaignBrowseViewAction.NextScreenAction.encounterDetail,
                navDest: .nextInStack,
                isActive: { $0.encounter.key == contents.key },
                initialState: {
                    if let encounter: Encounter = try? self.env.database.keyValueStore.get(
                        contents.key,
                        crashReporter: self.env.crashReporter
                    ) {
                        let runningEncounter: RunningEncounter? = encounter.runningEncounterKey
                            .flatMap { try? self.env.database.keyValueStore.get($0, crashReporter: self.env.crashReporter) }
                        return EncounterDetailViewState(building: encounter, running: runningEncounter)
                    } else {
                        return EncounterDetailViewState(building: Encounter(name: "", combatants: []))
                    }
                },
                destination: EncounterDetailView.init,
                label: label
            ).eraseToAnyView
        case .other: return label().eraseToAnyView
        }
    }

    func onDelete(_ indices: IndexSet) {
        guard let items = viewStore.state.sortedItems else { return }
        for i in indices {
            viewStore.send(.remove(items[i]))
        }
    }

    @ViewBuilder
    func sheetView(_ sheet: CampaignBrowseViewState.Sheet) -> some View {
        switch sheet {
        case .settings:
            SettingsContainerView().environmentObject(env)
        case .nodeEdit(let s):
            SheetNavigationContainer {
                NodeEditView(onDoneTap: { (state, node, title) in
                    viewStore.send(.didTapNodeEditDone(state, node, title))
                }, state: Binding(get: {
                    self.viewStore.state.nodeEditState ?? s
                }, set: {
                    if case .nodeEdit = viewStore.state.sheet {
                        self.viewStore.send(.sheet(.nodeEdit($0)))
                    }
                }))
            }
        case .move:
            SheetNavigationContainer {
                IfLetStore(self.store.scope(state: { $0.moveSheetState }, action: { .moveSheet($0) })) { store in
                    CampaignBrowseView(store: store)
                }
                .navigationBarTitleDisplayMode(.inline)
            }.environmentObject(env)
        }
    }

}

struct NodeEditView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let onDoneTap: (CampaignBrowseViewState.NodeEditState, CampaignNode?, String) -> Void

    @Binding var state: CampaignBrowseViewState.NodeEditState
    @State var didFocusOnField = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: state.contentType.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200.0, height: 200.0)

                HStack {
                    ClearableTextField("Name", text: $state.name, onCommit: self.saveAndDismissIfValid)
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
        .navigationBarTitle("\(state.node != nil ? "Rename" : "Add") \(state.contentType.displayName)", displayMode: .inline)
        .navigationBarItems(
            leading: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
            },
            trailing: Button(action: self.saveAndDismissIfValid) {
                Text("Done").bold()
            }.disabled(state.name.isEmpty)
        )
    }

    func saveAndDismissIfValid() {
        guard !state.name.isEmpty else { return }

        self.onDoneTap(self.state, self.state.node, self.state.name)
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
