import Foundation
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import GameModels
import Persistence

@Reducer
struct TabNavigationFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.entity(Preferences.key)) var preferences = Preferences()

        var selectedTab: Tabs = .campaign

        var campaignBrowser: CampaignBrowseViewFeature.State = CampaignBrowseViewFeature.State(node: CampaignNode.root, mode: .browse, items: .initial, showSettingsButton: true)
        var simpleAdventure: SimpleAdventureFeature.State = .init()
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

        var adventureTabMode: Preferences.AdventureTabMode {
            preferences.adventureTabMode ?? .simpleEncounter
        }

        static let nullInstance = State(
            selectedTab: .campaign,
            campaignBrowser: .nullInstance,
            simpleAdventure: .nullInstance,
            compendium: .nullInstance,
            diceRoller: .nullInstance
        )
    }

    enum Action: Equatable {
        case openEncounter(Encounter)
        case selectedTab(State.Tabs)
        case campaignBrowser(CampaignBrowseViewFeature.Action)
        case simpleAdventure(SimpleAdventureFeature.Action)
        case compendium(CompendiumIndexFeature.Action)
        case diceRoller(DiceRollerFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.campaignBrowser, action: \.campaignBrowser) {
            CampaignBrowseViewFeature()
        }
        Scope(state: \.simpleAdventure, action: \.simpleAdventure) {
            SimpleAdventureFeature()
        }
        Scope(state: \.compendium, action: \.compendium) {
            CompendiumRootFeature()
        }
        Scope(state: \.diceRoller, action: \.diceRoller) {
            DiceRollerFeature()
        }
        Reduce { state, action in
            switch action {
            case .openEncounter(let encounter):
                switch state.adventureTabMode {
                case .simpleEncounter:
                    state.simpleAdventure.encounter = SimpleAdventureFeature.State.makeScratchPadEncounterDetailState(encounter: encounter)
                case .campaignBrowser:
                    let detailState = EncounterDetailFeature.State(building: encounter)
                    return .send(.campaignBrowser(.setDestination(.encounter(detailState))))
                }
            case .selectedTab(let t):
                state.selectedTab = t
            case .campaignBrowser: break
            case .simpleAdventure: break
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
            switch adventureTabMode {
            case .simpleEncounter:
                nodes.append(contentsOf: simpleAdventure.navigationNodes)
            case .campaignBrowser:
                nodes.append(contentsOf: campaignBrowser.navigationNodes)
            }
        case .compendium:
            nodes.append(contentsOf: compendium.navigationNodes)
        case .diceRoller:
            break
        }
        return nodes
    }
}

@Reducer
struct SimpleAdventureFeature {
    @ObservableState
    struct State: Equatable {
        var encounter: EncounterDetailFeature.State = makeScratchPadEncounterDetailState(
            encounter: Encounter(id: Encounter.scratchPadEncounterId.rawValue, name: "Scratch pad", combatants: [])
        )
        var scratchPadRunningEncounterCount = 0

        @Presents var sheet: Sheet.State?

        static func makeScratchPadEncounterDetailState(
            encounter: Encounter,
            running: RunningEncounter? = nil
        ) -> EncounterDetailFeature.State {
            EncounterDetailFeature.State(
                building: encounter,
                running: running,
                navigationTitleOverride: "Encounter"
            )
        }

        static let nullInstance = State(
            encounter: .nullInstance,
            sheet: nil
        )

        var shouldShowNormalModeTip: Bool {
            scratchPadRunningEncounterCount >= 3
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case setSheet(Sheet.State?)
        case encounter(EncounterDetailFeature.Action)
        case sheet(PresentationAction<Sheet.Action>)
    }

    @Reducer
    struct Sheet {
        @ObservableState
        @CasePathable
        enum State: Equatable {
            case settings(SettingsFeature.State)
        }

        @CasePathable
        enum Action: Equatable {
            case settings(SettingsFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: \.settings, action: \.settings) {
                SettingsFeature()
            }
        }
    }

    @Dependency(\.crashReporter) var crashReporter
    @Dependency(\.database) var database

    var body: some ReducerOf<Self> {
        Scope(state: \.encounter, action: \.encounter) {
            EncounterDetailFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let encounter: Encounter = try? database.keyValueStore.get(
                    Encounter.key(Encounter.scratchPadEncounterId),
                    crashReporter: crashReporter
                ) else { break }

                let runningEncounter: RunningEncounter? = encounter.runningEncounterKey
                    .flatMap { try? database.keyValueStore.get($0, crashReporter: crashReporter) }
                state.encounter = State.makeScratchPadEncounterDetailState(
                    encounter: encounter,
                    running: runningEncounter
                )
                let runningEncounterPrefix = RunningEncounter.keyPrefix(for: Encounter.scratchPadEncounterId)
                state.scratchPadRunningEncounterCount = (try? database.keyValueStore.fetchMetadata(
                    .keyPrefix(runningEncounterPrefix.rawValue)
                ).count) ?? 0

            case .setSheet(let sheet):
                state.sheet = sheet

            case .sheet(.dismiss):
                state.sheet = nil

            case .encounter, .sheet:
                break
            }
            return .none
        }
        .ifLet(\.$sheet, action: \.sheet) {
            Sheet()
        }
    }
}

extension SimpleAdventureFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        [self] + encounter.navigationNodes
    }
}
