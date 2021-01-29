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

/// Manages a two-column campaign browse layout using the supplementary and secondary
/// columns of a split layout (managed by ColumnNavigationView).
///
/// The root view displayed by this view is either an encounter detail view or a campaign browse view.
struct CampaignBrowseTwoColumnContainerView: View {
    let store: Store<CampaignBrowseTwoColumnContainerState, CampaignBrowseTwoColumnContainerAction>

    var body: some View {
        Group {
            IfLetStore(store.scope(state: { $0.content.campaignBrowse}, action: { .contentCampaignBrowse($0) })) { store in
                CampaignBrowseView(store: store)
            }

            IfLetStore(store.scope(state: { $0.content.encounter }, action: { .contentEncounter($0) })) { store in
                EncounterDetailView(store: store)
            }
        }
        .background(
            WithViewStore(store, removeDuplicates: { $0.showReferenceView != $1.showReferenceView }) { viewStore in
                NavigationLink(
                    destination: ReferenceView(store: store.scope(state: { $0.referenceView }, action: { .referenceView($0) })),
                    isActive: Binding(get: { viewStore.state.showReferenceView }, set: { _ in })
                ) {
                    EmptyView()
                }
            }
        )
        .onAppear {
            ViewStore(store).send(.showReferenceView(true))
        }
    }
}

struct CampaignBrowseTwoColumnContainerState: Equatable {
    var content: Content
    var referenceView: ReferenceViewState

    var showReferenceView = false

    enum Content: Equatable {
        case browse(CampaignBrowseViewState)
        case encounter(EncounterDetailViewState)

        var campaignBrowse: CampaignBrowseViewState? {
            get {
                if case .browse(let b) = self {
                    return b
                }
                return nil
            }
            set {
                if let b = newValue {
                    self = .browse(b)
                }
            }
        }

        var encounter: EncounterDetailViewState? {
            get {
                if case .encounter(let e) = self {
                    return e
                }
                return nil
            }
            set {
                if let e = newValue {
                    self = .encounter(e)
                }
            }
        }

        var referenceContext: EncounterReferenceContext? {
            switch self {
            case .browse(let s): return s.referenceContext
            case .encounter(let s): return s.referenceContext
            }
        }

        var referenceItemRequests: [ReferenceViewItemRequest] {
            switch self {
            case .browse(let s): return s.referenceItemRequests
            case .encounter(let s): return s.referenceItemRequests
            }
        }

        var toReferenceContextAction: ((EncounterReferenceContextAction) -> CampaignBrowseTwoColumnContainerAction)? {
            switch self {
            case .browse(let s):
                if let nextToContextAction = s.toReferenceContextAction {
                    return { action in
                        .contentCampaignBrowse(nextToContextAction(action))
                    }
                }
            case .encounter(let s):
                return { action in
                    .contentEncounter(s.toReferenceContextAction(action))
                }
            }

            return nil
        }
    }
}

enum CampaignBrowseTwoColumnContainerAction: Equatable {
    case contentCampaignBrowse(CampaignBrowseViewAction)
    case contentEncounter(EncounterDetailViewState.Action)

    case referenceView(ReferenceViewAction)
    case showReferenceView(Bool)
}

extension CampaignBrowseTwoColumnContainerState {
    static let reducer: Reducer<Self, CampaignBrowseTwoColumnContainerAction, Environment> = Reducer.combine(
        Reducer { state, action, env in
            switch action {
            case .referenceView(.itemRequests(let items)):
                if items != state.referenceView.itemRequests {
                    state.showReferenceView = true
                }
                break
            case .showReferenceView(let b):
                state.showReferenceView = b
            case .referenceView: break // handled below
            case .contentCampaignBrowse: break // handled below
            case .contentEncounter: break // handled below
            }
            return .none
        },
        CampaignBrowseViewState.reducer.optional().pullback(state: \.content.campaignBrowse, action: /CampaignBrowseTwoColumnContainerAction.contentCampaignBrowse),
        EncounterDetailViewState.reducer.optional().pullback(state: \.content.encounter, action: /CampaignBrowseTwoColumnContainerAction.contentEncounter),
        ReferenceViewState.reducer.pullback(state: \.referenceView, action: /CampaignBrowseTwoColumnContainerAction.referenceView),
        Reducer { state, action, env in
            var actions: [CampaignBrowseTwoColumnContainerAction] = []

            let context = state.content.referenceContext
            if context != state.referenceView.context {
                state.referenceView.context = context
            }

            let itemRequests = state.content.referenceItemRequests
            if itemRequests != state.referenceView.itemRequests {
                actions.append(.referenceView(.itemRequests(itemRequests)))
            }

            if case .referenceView(.item(_, .inContext(let action))) = action {
                // forward to context
                if let toContext = state.content.toReferenceContextAction {
                    actions.append(toContext(action))
                }
            }

            return actions.publisher.eraseToEffect()
        }
    )

    init(node: CampaignNode) {
        self.content = .browse(CampaignBrowseViewState(node: node, mode: .browse, showSettingsButton: false))
        self.referenceView = ReferenceViewState(items: IdentifiedArray([]))
    }

    init(encounter: Encounter) {
        self.content = .encounter(EncounterDetailViewState(building: encounter))
        self.referenceView = ReferenceViewState(items: IdentifiedArray([]))
    }

    init() {
        self.content = .browse(CampaignBrowseViewState(node: .root, mode: .browse, showSettingsButton: false))
        self.referenceView = ReferenceViewState(items: IdentifiedArray([]))
    }
}

extension CampaignBrowseTwoColumnContainerState: NavigationNode {
    func topNavigationItems() -> [Any] {
        switch content {
        case .browse(let b): return b.topNavigationItems()
        case .encounter(let e): return e.topNavigationItems()
        }
    }

    func navigationStackSize() -> Int {
        switch content {
        case .browse(let b): return b.navigationStackSize()
        case .encounter(let e): return e.navigationStackSize()
        }
    }

    mutating func popLastNavigationStackItem() {
        switch content {
        case .browse(var b):
            b.popLastNavigationStackItem()
            content = .browse(b)
        case .encounter(var e):
            e.popLastNavigationStackItem()
            content = .encounter(e)
        }
    }
}

extension CampaignBrowseTwoColumnContainerState {
    static let nullInstance = CampaignBrowseTwoColumnContainerState(node: .root)
}
