//
//  ColumnNavigationViewState.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Dice
import GameModels

struct ColumnNavigationViewState: Equatable {
    var campaignBrowse = CampaignBrowseViewFeature.State(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
    var referenceView = ReferenceViewState.defaultInstance

    var diceCalculator = FloatingDiceRollerViewState(diceCalculator: DiceCalculator.State(
        displayOutcomeExternally: false,
        rollOnAppear: false,
        expression: .dice(count: 1, die: Die(sides: 20)),
        mode: .rollingExpression
    ))

    var topNavigationItems: [Any] {
        var res = campaignBrowse.topNavigationItems()

        if let ref = referenceView.selectedItemNavigationNode?.topNavigationItems() {
            res.append(ref)
        }
        
        return res
    }
}

enum ColumnNavigationViewAction: Equatable {
    case diceCalculator(FloatingDiceRollerViewAction)
    case campaignBrowse(CampaignBrowseViewFeature.Action)
    case referenceView(ReferenceViewAction)
}

extension ColumnNavigationViewState {
    static let reducer: AnyReducer<Self, ColumnNavigationViewAction, Environment> = AnyReducer.combine(
        FloatingDiceRollerViewState.reducer.pullback(state: \.diceCalculator, action: /ColumnNavigationViewAction.diceCalculator),
        AnyReducer { env in
            CampaignBrowseViewFeature(environment: env)
        }
        .pullback(state: \.campaignBrowse, action: /ColumnNavigationViewAction.campaignBrowse),
        ReferenceViewState.reducer.pullback(state: \.referenceView, action: /ColumnNavigationViewAction.referenceView),
        AnyReducer { state, action, env in
            switch action {
            case .campaignBrowse, .referenceView:
                if state.diceCalculator.canCollapse {
                    return .send(.diceCalculator(.collapse), animation: .default)
                }
            default: break
            }
            return .none
        },
        // manages interactions between the left column and reference view
        AnyReducer { state, action, env in
            var actions: [ColumnNavigationViewAction] = []

            let encounterContext = state.campaignBrowse.referenceContext
            if encounterContext != state.referenceView.encounterReferenceContext {
                state.referenceView.encounterReferenceContext = encounterContext
            }

            let itemRequests = state.campaignBrowse.referenceItemRequests + state.referenceView.referenceItemRequests
            if itemRequests != state.referenceView.itemRequests {
                actions.append(.referenceView(.itemRequests(itemRequests)))
            }

            if case .referenceView(.item(_, .inEncounterDetailContext(let action))) = action {
                // forward to context
                if let toContext = state.campaignBrowse.toReferenceContextAction {
                    actions.append(.campaignBrowse(toContext(action)))
                }
            }

            if case .referenceView(.removeTab(let id)) = action,
               state.referenceView.itemRequests.contains(where: { $0.id == id }) {
                // inform context of removal
                if let toContext = state.campaignBrowse.toReferenceContextAction {
                    actions.append(.campaignBrowse(toContext(.didDismiss(id))))
                }
            }

            return .merge(actions.map { .send($0) })
        }
    )

    static let nullInstance = ColumnNavigationViewState()

}
