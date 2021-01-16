//
//  CampaignBrowseTwoColumnContainer.swift
//  Construct
//
//  Created by Thomas Visser on 24/12/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CampaignBrowseTwoColumnContainerView: View {
    let store: Store<CampaignBrowseTwoColumnContainerState, CampaignBrowseTwoColumnContainerAction>

    var body: some View {
        CampaignBrowseView(store: store.scope(state: { $0.campaignBrowse }, action: { .campaignBrowse($0) }))
            .background(
                WithViewStore(store) { viewStore in
                    NavigationLink(
                        destination: ReferenceView(store: store.scope(state: { $0.referenceView }, action: { .referenceView($0) })),
                        isActive: Binding(get: { viewStore.state.showReferenceView }, set: { _ in })
                    ) {
                        EmptyView()
                    }
                }
            )
    }
}

struct CampaignBrowseTwoColumnContainerState: Equatable {
    var campaignBrowse: CampaignBrowseViewState
    var referenceView: ReferenceViewState

    var showReferenceView = false
}

enum CampaignBrowseTwoColumnContainerAction: Equatable {
    case campaignBrowse(CampaignBrowseViewAction)
    case referenceView(ReferenceViewAction)
}

extension CampaignBrowseTwoColumnContainerState {
    static let reducer: Reducer<Self, CampaignBrowseTwoColumnContainerAction, Environment> = Reducer.combine(
        Reducer { state, action, env in
            switch action {
            case .referenceView(.remoteItemRequests(let items)):
                if items != state.referenceView.remoteItemRequests {
                    state.showReferenceView = true
                }
                break
            case .referenceView: break // handled below
            case .campaignBrowse: break // handled below
            }
            return .none
        },
        CampaignBrowseViewState.reducer.pullback(state: \.campaignBrowse, action: /CampaignBrowseTwoColumnContainerAction.campaignBrowse),
        ReferenceViewState.reducer.pullback(state: \.referenceView, action: /CampaignBrowseTwoColumnContainerAction.referenceView)
    )

    init(node: CampaignNode) {
        self.campaignBrowse = CampaignBrowseViewState(node: node, mode: .browse, showSettingsButton: false)
        self.referenceView = ReferenceViewState(items: IdentifiedArray([]))
    }

    init() {
        self.campaignBrowse = CampaignBrowseViewState(node: .root, mode: .browse, showSettingsButton: false)
        self.referenceView = ReferenceViewState(items: IdentifiedArray([]))
    }
}

extension CampaignBrowseTwoColumnContainerState: NavigationNode {
    func topNavigationItems() -> [Any] {
        campaignBrowse.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        campaignBrowse.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        campaignBrowse.popLastNavigationStackItem()
    }


}
