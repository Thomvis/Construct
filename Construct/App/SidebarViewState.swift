//
//  SidebarViewState.swift
//  Construct
//
//  Created by Thomas Visser on 29/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths

struct SidebarViewState: Equatable, NavigationStackSourceState {

    var campaignNodes: [UUID: [CampaignNode]] = [:]
    var campaignNodeIsExpanded: [UUID: Bool] = [:]

    var presentedScreens: [NavigationDestination: NextScreen] = [
        .detail: .campaignBrowse(CampaignBrowseTwoColumnContainerState())
    ]
    var sheet: Sheet?

    func nodes(in node: CampaignNode) -> [CampaignNode]? {
        campaignNodes[node.id]?.filter { $0.special == nil && $0.contents == nil }
    }

    var nodeEditState: CampaignBrowseViewState.NodeEditState? {
        guard case .nodeEdit(let s)? = sheet else { return nil }
        return s
    }

    var referenceViewState: ReferenceViewState? {
        presentedDetailCampaignBrowse?.referenceView
    }

    enum NextScreen: Equatable {
        case compendium(CompendiumIndexState)
        case campaignBrowse(CampaignBrowseTwoColumnContainerState)
    }

    enum Sheet: Equatable, Identifiable {
        case nodeEdit(CampaignBrowseViewState.NodeEditState)

        var id: String {
            switch self {
            case .nodeEdit(let s): return s.id.uuidString
            }
        }
    }

}

enum SidebarViewAction: NavigationStackSourceAction, Equatable {
    case loadCampaignNode(CampaignNode)
    case campaignNodeIsExpanded(CampaignNode, Bool)
    case didTapCampaignNodeEditDone(CampaignBrowseViewState.NodeEditState, CampaignNode?, String)

    case onCampaignNodeTap(CampaignNode)

    case setNextScreen(SidebarViewState.NextScreen?)
    indirect case nextScreen(NextScreenAction)
    case setDetailScreen(SidebarViewState.NextScreen?)
    indirect case detailScreen(NextScreenAction)

    case setSheet(SidebarViewState.Sheet?)

    static func presentScreen(_ destination: NavigationDestination, _ screen: SidebarViewState.NextScreen?) -> Self {
        switch destination {
        case .nextInStack: return .setNextScreen(screen)
        case .detail: return .setDetailScreen(screen)
        }
    }

    static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self {
        switch destination {
        case .nextInStack: return .nextScreen(action)
        case .detail: return .detailScreen(action)
        }
    }

    enum NextScreenAction: Equatable {
        case compendium(CompendiumIndexAction)
        case encounter(EncounterDetailViewState.Action)
        case campaignBrowse(CampaignBrowseTwoColumnContainerAction)
    }

}

extension SidebarViewState: NavigationStackItemState {
    var navigationStackItemStateId: String { "sidebar" }
    var navigationTitle: String { "Construct" }
}

extension SidebarViewState {
    static let reducer: Reducer<Self, SidebarViewAction, Environment> = Reducer.combine(
        CompendiumIndexState.reducer.optional().pullback(state: \.presentedDetailCompendium, action: /SidebarViewAction.detailScreen..SidebarViewAction.NextScreenAction.compendium),
        CampaignBrowseTwoColumnContainerState.reducer.optional().pullback(state: \.presentedDetailCampaignBrowse, action: /SidebarViewAction.detailScreen..SidebarViewAction.NextScreenAction.campaignBrowse),
        Reducer { state, action, env in
            switch action {
            case .loadCampaignNode(let node):
                let nodes = (try? env.campaignBrowser.nodes(in: node)) ?? []
                state.campaignNodes[node.id] = nodes
            case .campaignNodeIsExpanded(let node, let bool):
                state.campaignNodeIsExpanded[node.id] = bool
                return Effect(value: .loadCampaignNode(node))
            case .didTapCampaignNodeEditDone(let s, let n, let t):
                var browseState = CampaignBrowseViewState.nullInstance
                return CampaignBrowseViewState.reducer.run(&browseState, .didTapNodeEditDone(s, n, t), env).collect().map { _ in
                        .loadCampaignNode(CampaignNode.root)
                    }.eraseToEffect()
            case .onCampaignNodeTap(let node):
                return [
                    node.contents == nil ? .campaignNodeIsExpanded(node, true) : nil,
                    .setDetailScreen(.campaignBrowse(CampaignBrowseTwoColumnContainerState(node: node, referenceView: state.referenceViewState)))
                ].compactMap { $0 }.publisher.eraseToEffect()
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .nextScreen: break // handled above
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .detailScreen: break // handled above
            case .setSheet(let s):
                state.sheet = s
            }
            return .none
        }
    )
}
