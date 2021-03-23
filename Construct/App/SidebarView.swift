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
        WithViewStore(store.scope(state: { LocalState($0) })) { viewStore in
            List {
                StateDrivenNavigationLink(
                    store: store,
                    state: /SidebarViewState.NextScreen.campaignBrowse,
                    action: /SidebarViewAction.NextScreenAction.campaignBrowse,
                    navDest: .detail,
                    isActive: { $0.content.encounterState?.encounter.key == Encounter.key(Encounter.scratchPadEncounterId) },
                    initialState: {
                        if let encounter: Encounter = try? self.env.database.keyValueStore.get(Encounter.key(Encounter.scratchPadEncounterId)) {
                            return CampaignBrowseTwoColumnContainerState(encounter: encounter, referenceView: .defaultInstance)
                        } else {
                            return CampaignBrowseTwoColumnContainerState.nullInstance
                        }
                    },
                    destination: CampaignBrowseTwoColumnContainerView.init
                ) {
                    Label("Scatch pad encounter", systemImage: "shield")
                }

                adventureSection(viewStore)

                compendiumSection(viewStore)
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Construct")
            .sheet(item: viewStore.binding(get: \.sheet) { _ in .setSheet(nil) }, content: self.sheetView)
            .onAppear {
                viewStore.send(.loadCampaignNode(CampaignNode.root))
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: {
                        viewStore.send(.onDiceRollerButtonTap)
                    }) {
                        HStack {
                            Image("tabbar_d20")
                            Text("Dice roller")
                        }
                    }
                }

                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        viewStore.send(.setSheet(.about))
                    }) {
                        Text("About")
                    }
                }
            }
        }
    }

    @ViewBuilder
    func adventureSection(_ viewStore: ViewStore<LocalState, SidebarViewAction>) -> some View {
        Section(header: Text("Adventure")) {
            StateDrivenNavigationLink(
                store: store,
                state: /SidebarViewState.NextScreen.campaignBrowse,
                action: /SidebarViewAction.NextScreenAction.campaignBrowse,
                navDest: .detail,
                isActive: { $0.content.browseState?.node == CampaignNode.root && $0.content.browseState?.presentedScreens.isEmpty == true },
                initialState: CampaignBrowseTwoColumnContainerState(node: .root, referenceView: .defaultInstance),
                destination: CampaignBrowseTwoColumnContainerView.init
            ) {
                Label("All encounters", systemImage: "shield")
            }

            campaignNodes(in: CampaignNode.root, viewStore: viewStore)
        }
    }

    @ViewBuilder
    func compendiumSection(_ viewStore: ViewStore<LocalState, SidebarViewAction>) -> some View {
        Section(header: Text("Compendium")) {
            ForEach([
                CompendiumItemType.monster,
                CompendiumItemType.character,
                CompendiumItemType.group,
                CompendiumItemType.spell
            ], id: \.self) { type in
                StateDrivenNavigationLink(
                    store: store,
                    state: /SidebarViewState.NextScreen.compendium,
                    action: /SidebarViewAction.NextScreenAction.compendium,
                    navDest: .detail,
                    isActive: { $0.title == type.localizedScreenDisplayName }, // not great
                    initialState: CompendiumIndexState(
                        title: type.localizedScreenDisplayName,
                        properties: CompendiumIndexState.Properties(
                            showImport: type == CompendiumItemType.monster,
                            showAdd: true,
                            initiallyFocusOnSearch: false,
                            initialContent: .searchResults
                        ),
                        results: CompendiumIndexState.RS.initial(type: type)
                    ),
                    destination: { CompendiumIndexView(store: $0).id(type.localizedScreenDisplayName) }
                ) {
                    Text(type.localizedScreenDisplayName)
                }
            }
        }
    }

    @ViewBuilder
    func campaignNodes(in node: CampaignNode, viewStore: ViewStore<LocalState, SidebarViewAction>) -> some View {
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
                    isActive: { $0.content.browseState?.node == node && $0.content.browseState?.presentedScreens.isEmpty == true },
                    initialState: CampaignBrowseTwoColumnContainerState(node: node),
                    destination: CampaignBrowseTwoColumnContainerView.init
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
            case .about:
                SettingsContainerView().environmentObject(env)
            }
        }
        .eraseToAnyView
    }

    struct LocalState: Equatable {
        var presentedScreenIds: [NavigationDestination: String]
        @EqKey({ $0?.id })
        var sheet: SidebarViewState.Sheet?

        var campaignNodes: [UUID: [CampaignNode]] = [:]
        var campaignNodeIsExpanded: [UUID: Bool] = [:]

        init(_ state: SidebarViewState) {
            presentedScreenIds = state.presentedScreens.mapValues {
                $0.nodeId
            }
            self.sheet = state.sheet
            self.campaignNodes = state.campaignNodes
            self.campaignNodeIsExpanded = state.campaignNodeIsExpanded
        }

        func nodes(in node: CampaignNode) -> [CampaignNode]? {
            campaignNodes[node.id]?.filter { $0.special == nil && $0.contents == nil }
        }
    }
}
