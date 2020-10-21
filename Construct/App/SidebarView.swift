//
//  SidebarView.swift
//  Construct
//
//  Created by Thomas Visser on 29/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct SidebarView: View {
    @EnvironmentObject var env: Environment

    let store: Store<SidebarViewState, SidebarViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            List {
                StateDrivenNavigationLink(
                    store: store,
                    state: /SidebarViewState.NextScreen.encounter,
                    action: /SidebarViewAction.NextScreenAction.encounter,
                    navDest: .detail,
                    isActive: { $0.encounter.key == Encounter.key(Encounter.scratchPadEncounterId) },
                    initialState: {
                        if let encounter: Encounter = try? self.env.database.keyValueStore.get(Encounter.key(Encounter.scratchPadEncounterId)) {
                            return EncounterDetailViewState(building: encounter)
                        } else {
                            return EncounterDetailViewState.nullInstance
                        }
                    },
                    destination: { EncounterDetailView(store: $0) }
                ) {
                    Label("Scatch pad encounter", systemImage: "shield")
                }

                adventureSection(viewStore)

                Section(header: Text("Compendium")) {
                    StateDrivenNavigationLink(
                        store: store,
                        state: /SidebarViewState.NextScreen.compendium,
                        action: /SidebarViewAction.NextScreenAction.compendium,
                        navDest: .detail,
                        isActive: { $0.title == "Monsters" }, // not great
                        initialState: CompendiumIndexState(title: "Monsters", properties: .secondary, results: .initial(type: .monster)),
                        destination: { CompendiumIndexView(store: $0) }
                    ) {
                        Text("Monsters")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Characters")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Adventuring Parties")
                    }

                    NavigationLink(destination: EmptyView()) {
                        Text("Spells")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Construct")
            .sheet(item: viewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
            .onAppear {
                viewStore.send(.loadCampaignNode(CampaignNode.root))
            }
        }
    }

    @ViewBuilder
    func adventureSection(_ viewStore: ViewStore<SidebarViewState, SidebarViewAction>) -> some View {
        Section(header: Text("Adventure")) {
            StateDrivenNavigationLink(
                store: store,
                state: /SidebarViewState.NextScreen.campaignBrowse,
                action: /SidebarViewAction.NextScreenAction.campaignBrowse,
                navDest: .detail,
                isActive: { $0.node == CampaignNode.root && $0.presentedScreens.isEmpty },
                initialState: CampaignBrowseViewState(node: CampaignNode.root, mode: .browse, showSettingsButton: false),
                destination: CampaignBrowseView.init
            ) {
                Label("All encounters", systemImage: "shield")
            }

            campaignNodes(in: CampaignNode.root, viewStore: viewStore)

//            SimpleAccentedButton(action: {
//                viewStore.send(.setSheet(.nodeEdit(CampaignBrowseViewState.NodeEditState(name: "", contentType: .encounter))))
//            }) {
//                Label("New encounter", systemImage: "shield")
//            }
//
//            SimpleAccentedButton(action: {
//                viewStore.send(.setSheet(.nodeEdit(CampaignBrowseViewState.NodeEditState(name: ""))))
//            }) {
//                Label("New group", systemImage: "folder")
//            }
        }
    }

    @ViewBuilder
    func campaignNodes(in node: CampaignNode, viewStore: ViewStore<SidebarViewState, SidebarViewAction>) -> some View {
        ForEach(viewStore.state.nodes(in: node) ?? [], id: \.id) { node in
            DisclosureGroup(isExpanded: Binding(get: {
                viewStore.campaignNodeIsExpanded[node.id] ?? false
            }, set: {
                viewStore.send(.campaignNodeIsExpanded(node, $0))
            }), content: {
                campaignNodes(in: node, viewStore: viewStore).eraseToAnyView
            }, label: {
                StateDrivenNavigationLink(
                    store: store,
                    state: /SidebarViewState.NextScreen.campaignBrowse,
                    action: /SidebarViewAction.NextScreenAction.campaignBrowse,
                    navDest: .detail,
                    isActive: { $0.node == node && $0.presentedScreens.isEmpty },
                    initialState: CampaignBrowseViewState(node: node, mode: .browse, showSettingsButton: false),
                    destination: CampaignBrowseView.init
                ) {
                    Label(node.title, systemImage: node.iconName)
                }
            })
        }
    }

    func sheetView(_ sheet: SidebarViewState.Sheet) -> AnyView {
        return WithViewStore(store) { viewStore in
            switch sheet {
            case .nodeEdit(let s):
                NodeEditView(
                    onDoneTap: { (state, node, title) in
                        viewStore.send(.didTapCampaignNodeEditDone(state, node, title))
                    },
                    state: Binding(get: {
                        viewStore.state.nodeEditState ?? s
                    }, set: {
                        viewStore.send(.setSheet(.nodeEdit($0)))
                    })
                )
            }
        }
        .eraseToAnyView
    }
}
