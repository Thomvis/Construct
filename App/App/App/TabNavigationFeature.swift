import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import GameModels

struct TabNavigationFeature: Reducer {

    struct State: Equatable {
        var selectedTab: Tabs = .campaign

        var campaignBrowser: CampaignBrowseViewFeature.State = CampaignBrowseViewFeature.State(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
        var compendium: CompendiumIndexFeature.State = CompendiumIndexFeature.State(
            title: "Compendium",
            properties: .init(
                showImport: true,
                showAdd: true,
                typeRestriction: nil
            ), results: .initial
        )
        var diceRoller: DiceRollerFeature.State = DiceRollerFeature.State()

        enum Tabs: Int {
            case campaign
            case compendium
            case diceRoller
        }

        static let nullInstance = State(
            selectedTab: .campaign,
            campaignBrowser: .nullInstance,
            compendium: .nullInstance,
            diceRoller: .nullInstance
        )
    }

    enum Action: Equatable {
        case selectedTab(State.Tabs)
        case campaignBrowser(CampaignBrowseViewFeature.Action)
        case compendium(CompendiumIndexFeature.Action)
        case diceRoller(DiceRollerFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.campaignBrowser, action: /Action.campaignBrowser) {
            CampaignBrowseViewFeature()
        }
        Scope(state: \.compendium, action: /Action.compendium) {
            CompendiumRootFeature()
        }
        Scope(state: \.diceRoller, action: /Action.diceRoller) {
            DiceRollerFeature()
        }
        Reduce { state, action in
            switch action {
            case .selectedTab(let t):
                state.selectedTab = t
            case .campaignBrowser: break
            case .compendium: break
            case .diceRoller: break
            }
            return .none
        }
    }
}

extension TabNavigationFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        var nodes: [Any] = [self]
        switch selectedTab {
        case .campaign:
            nodes.append(contentsOf: campaignBrowser.navigationNodes)
        case .compendium:
            nodes.append(contentsOf: compendium.navigationNodes)
        case .diceRoller:
            break
        }
        return nodes
    }
}
