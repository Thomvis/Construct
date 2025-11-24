import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Dice
import GameModels
import Helpers

@Reducer
struct ColumnNavigationFeature {

    @ObservableState
    struct State: Equatable {
        var campaignBrowse = CampaignBrowseViewFeature.State(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
        var referenceView = ReferenceViewFeature.State.defaultInstance

        var diceCalculator = FloatingDiceRollerFeature.State(diceCalculator: DiceCalculator.State(
            displayOutcomeExternally: false,
            rollOnAppear: false,
            expression: .dice(count: 1, die: Die(sides: 20)),
            mode: .rollingExpression
        ))

        static let nullInstance = State()
    }

    enum Action: Equatable {
        case diceCalculator(FloatingDiceRollerFeature.Action)
        case campaignBrowse(CampaignBrowseViewFeature.Action)
        case referenceView(ReferenceViewFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.diceCalculator, action: \.diceCalculator) {
            FloatingDiceRollerFeature()
        }
        Scope(state: \.campaignBrowse, action: \.campaignBrowse) {
            CampaignBrowseViewFeature()
        }
        Scope(state: \.referenceView, action: \.referenceView) {
            ReferenceViewFeature()
        }

        Reduce { state, action in
            var effects: [Effect<Action>] = []

            switch action {
            case .campaignBrowse, .referenceView:
                if state.diceCalculator.canCollapse {
                    effects.append(.send(.diceCalculator(.collapse), animation: .default))
                }
            default:
                break
            }

            var followUpActions: [Action] = []

            let encounterContext = state.campaignBrowse.referenceContext
            if encounterContext != state.referenceView.encounterReferenceContext {
                state.referenceView.encounterReferenceContext = encounterContext
            }

            let itemRequests = state.campaignBrowse.referenceItemRequests + state.referenceView.referenceItemRequests
            if itemRequests != state.referenceView.itemRequests {
                followUpActions.append(.referenceView(.itemRequests(itemRequests)))
            }

            if case .referenceView(.item(.element(id: _, action: .inEncounterDetailContext(let action)))) = action {
                if let toContext = state.campaignBrowse.toReferenceContextAction {
                    followUpActions.append(.campaignBrowse(toContext(action)))
                }
            }

            if case .referenceView(.removeTab(let id)) = action,
               state.referenceView.itemRequests.contains(where: { $0.id == id }) {
                if let toContext = state.campaignBrowse.toReferenceContextAction {
                    followUpActions.append(.campaignBrowse(toContext(.didDismiss(id))))
                }
            }

            if !followUpActions.isEmpty {
                effects.append(.merge(followUpActions.map { .send($0) }))
            }

            return .merge(effects)
        }
    }
}

extension ColumnNavigationFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        var nodes: [Any] = [self]
        nodes.append(contentsOf: campaignBrowse.navigationNodes)
        if let ref = referenceView.selectedItemNavigationNodes {
            nodes.append(contentsOf: ref)
        }
        return nodes
    }
}
