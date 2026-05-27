import ComposableArchitecture
@testable import Construct
import GameModels
import XCTest

@MainActor
final class SimpleAdventureFeatureTest: XCTestCase {

    func testSettingsSampleEncounterRestoredUpdatesVisibleScratchPadEncounter() async {
        let restoredEncounter = Encounter(
            id: Encounter.scratchPadEncounterId.rawValue,
            name: "Sample encounter",
            combatants: []
        )

        let store = TestStore(initialState: SimpleAdventureFeature.State(
            encounter: SimpleAdventureFeature.State.makeScratchPadEncounterDetailState(
                encounter: Encounter(
                    id: Encounter.scratchPadEncounterId.rawValue,
                    name: "Scratch pad",
                    combatants: []
                )
            ),
            sheet: .settings(SettingsFeature.State())
        )) {
            SimpleAdventureFeature()
        }
        store.exhaustivity = .off

        await store.send(.sheet(.presented(.settings(.delegate(.sampleEncounterRestored(
            restoredEncounter,
            openInCampaignBrowser: false
        )))))) {
            $0.encounter.building = restoredEncounter
            $0.encounter.running = nil
            $0.encounter.navigationTitleOverride = "Encounter"
        }
    }

    func testSettingsSampleEncounterRestoredOpensTopLevelEncounterInCampaignBrowser() async {
        let scratchPad = Encounter(
            id: Encounter.scratchPadEncounterId.rawValue,
            name: "Scratch pad",
            combatants: []
        )
        let topLevelEncounter = Encounter(name: "Sample encounter", combatants: [])

        let store = TestStore(initialState: SimpleAdventureFeature.State(
            encounter: SimpleAdventureFeature.State.makeScratchPadEncounterDetailState(
                encounter: scratchPad
            ),
            sheet: .settings(SettingsFeature.State())
        )) {
            SimpleAdventureFeature()
        }
        store.exhaustivity = .off

        await store.send(.sheet(.presented(.settings(.delegate(.sampleEncounterRestored(
            topLevelEncounter,
            openInCampaignBrowser: true
        )))))) {
            $0.encounter.building = scratchPad
            $0.sheet = nil
        }
        await store.receive(.delegate(.openEncounterInCampaignBrowser(topLevelEncounter)))
    }
}
