import GameModels

protocol AdventureNavigationState {
    var adventureTabMode: Preferences.AdventureTabMode { get }
    var campaignBrowser: CampaignBrowseViewFeature.State { get set }
    var simpleAdventure: SimpleAdventureFeature.State { get set }
}

extension AdventureNavigationState {
    mutating func openEncounter(_ encounter: Encounter) {
        switch adventureTabMode {
        case .simpleEncounter:
            simpleAdventure.encounter = SimpleAdventureFeature.State.makeScratchPadEncounterDetailState(encounter: encounter)
        case .campaignBrowser:
            openEncounterInCampaignBrowser(encounter)
        }
    }

    mutating func openEncounterInCampaignBrowser(_ encounter: Encounter) {
        campaignBrowser.destination = .encounter(EncounterDetailFeature.State(building: encounter))
    }

    var adventureNavigationNodes: [Any] {
        switch adventureTabMode {
        case .simpleEncounter:
            return simpleAdventure.navigationNodes
        case .campaignBrowser:
            return campaignBrowser.navigationNodes
        }
    }

    var campaignBrowserForColumnNavigation: CampaignBrowseViewFeature.State {
        campaignBrowser
    }

    var simpleAdventureForTabNavigation: SimpleAdventureFeature.State {
        var state = simpleAdventure
        if case .campaignBrowser = adventureTabMode,
           case let .encounter(encounterState)? = campaignBrowser.destination {
            state.encounter = encounterState
        }
        return state
    }
}

extension TabNavigationFeature.State: AdventureNavigationState {}

extension ColumnNavigationFeature.State: AdventureNavigationState {
    var campaignBrowser: CampaignBrowseViewFeature.State {
        get { campaignBrowse }
        set { campaignBrowse = newValue }
    }
}
