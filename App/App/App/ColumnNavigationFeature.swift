import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Dice
import GameModels
import Helpers
import Persistence

@Reducer
struct ColumnNavigationFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.entity(Preferences.key)) var preferences = Preferences()

        var campaignBrowse = CampaignBrowseViewFeature.State(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
        var simpleAdventure: SimpleAdventureFeature.State = .init()
        var referenceView = ReferenceViewFeature.State.defaultInstance

        var diceCalculator = FloatingDiceRollerFeature.State(diceCalculator: DiceCalculator.State(
            displayOutcomeExternally: false,
            rollOnAppear: false,
            expression: .dice(count: 1, die: Die(sides: 20)),
            mode: .rollingExpression
        ))

        var adventureTabMode: Preferences.AdventureTabMode {
            preferences.adventureTabMode ?? .simpleEncounter
        }

    }

    enum Action: Equatable {
        case diceCalculator(FloatingDiceRollerFeature.Action)
        case campaignBrowse(CampaignBrowseViewFeature.Action)
        case simpleAdventure(SimpleAdventureFeature.Action)
        case referenceView(ReferenceViewFeature.Action)
        case openEncounter(Encounter)
        case openEncounterInCampaignBrowser(Encounter)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.diceCalculator, action: \.diceCalculator) {
            FloatingDiceRollerFeature()
        }
        Scope(state: \.campaignBrowse, action: \.campaignBrowse) {
            CampaignBrowseViewFeature()
        }
        Scope(state: \.simpleAdventure, action: \.simpleAdventure) {
            SimpleAdventureFeature()
        }
        Scope(state: \.referenceView, action: \.referenceView) {
            ReferenceViewFeature()
        }

        Reduce { state, action in
            var effects: [Effect<Action>] = []

            switch action {
            case .simpleAdventure(.delegate(.openEncounterInCampaignBrowser(let encounter))):
                if state.diceCalculator.canCollapse {
                    effects.append(.send(.diceCalculator(.collapse), animation: .default))
                }
                effects.append(.send(.openEncounterInCampaignBrowser(encounter)))
            case .campaignBrowse, .simpleAdventure, .referenceView:
                if state.diceCalculator.canCollapse {
                    effects.append(.send(.diceCalculator(.collapse), animation: .default))
                }
            case .openEncounter(let encounter):
                state.openEncounter(encounter)
            case .openEncounterInCampaignBrowser(let encounter):
                state.$preferences.withLock { $0.adventureTabMode = .campaignBrowser }
                state.openEncounterInCampaignBrowser(encounter)
            case .diceCalculator:
                break
            }

            var followUpActions: [Action] = []

            let encounterContext: EncounterReferenceContext?
            let encounterReferenceItemRequests: [ReferenceViewItemRequest]
            let toEncounterReferenceContextAction: ((EncounterReferenceContextAction) -> Action)?
            switch state.adventureTabMode {
            case .simpleEncounter:
                encounterContext = state.simpleAdventure.encounter.referenceContext
                encounterReferenceItemRequests = state.simpleAdventure.encounter.referenceItemRequests
                let toContext = state.simpleAdventure.encounter.toReferenceContextAction
                toEncounterReferenceContextAction = {
                    .simpleAdventure(.encounter(toContext($0)))
                }
            case .campaignBrowser:
                encounterContext = state.campaignBrowse.referenceContext
                encounterReferenceItemRequests = state.campaignBrowse.referenceItemRequests
                toEncounterReferenceContextAction = state.campaignBrowse.toReferenceContextAction.map { toContext in
                    { .campaignBrowse(toContext($0)) }
                }
            }

            if encounterContext != state.referenceView.encounterReferenceContext {
                state.referenceView.encounterReferenceContext = encounterContext
            }

            let itemRequests = encounterReferenceItemRequests + state.referenceView.referenceItemRequests
            if itemRequests != state.referenceView.itemRequests {
                followUpActions.append(.referenceView(.itemRequests(itemRequests)))
            }

            if case .referenceView(.item(.element(id: _, action: .inEncounterDetailContext(let action)))) = action {
                if let toEncounterReferenceContextAction {
                    followUpActions.append(toEncounterReferenceContextAction(action))
                }
            }

            if case .referenceView(.removeTab(let id)) = action,
               state.referenceView.itemRequests.contains(where: { $0.id == id }) {
                if let toEncounterReferenceContextAction {
                    followUpActions.append(toEncounterReferenceContextAction(.didDismiss(id)))
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
        nodes.append(contentsOf: adventureNavigationNodes)
        if let ref = referenceView.selectedItemNavigationNodes {
            nodes.append(contentsOf: ref)
        }
        return nodes
    }
}
