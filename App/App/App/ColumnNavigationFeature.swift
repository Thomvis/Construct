import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Dice
import GameModels
import Helpers

struct ColumnNavigationFeature: Reducer {
    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

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
        Reduce { state, action in
            switch action {
            case .campaignBrowse, .referenceView:
                if state.diceCalculator.canCollapse {
                    return .send(.diceCalculator(.collapse), animation: .default)
                }
            default: break
            }
            return .none
        }

        Reduce { state, action in
            var actions: [Action] = []

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

        Scope(state: \.diceCalculator, action: /Action.diceCalculator) {
            FloatingDiceRollerFeature(environment: environment)
        }
        Scope(state: \.campaignBrowse, action: /Action.campaignBrowse) {
            CampaignBrowseViewFeature(environment: environment)
        }
        Scope(state: \.referenceView, action: /Action.referenceView) {
            ReferenceViewFeature(environment: environment)
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
