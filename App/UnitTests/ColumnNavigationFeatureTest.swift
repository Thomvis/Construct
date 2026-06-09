import ComposableArchitecture
@testable import Construct
import GameModels
import Persistence
import TestSupport
import XCTest

@MainActor
final class ColumnNavigationFeatureTest: XCTestCase {

    func testTabToColumnConversionDoesNotSeedCampaignBrowserInSimpleMode() {
        var tabState = TabNavigationFeature.State()
        let encounter = Encounter(name: "Simple encounter", combatants: [])
        tabState.simpleAdventure.encounter = SimpleAdventureFeature.State.makeScratchPadEncounterDetailState(
            encounter: encounter
        )

        let columnState = tabState.columnNavigationViewState

        XCTAssertEqual(columnState.simpleAdventure.encounter.building, encounter)
        XCTAssertNil(columnState.campaignBrowse.destination)
    }

    func testOpenEncounterUsesSimpleAdventureInSimpleMode() async throws {
        let encounter = Encounter(name: "Simple encounter", combatants: [])
        let store = try await makeStore(adventureTabMode: .simpleEncounter)

        await store.send(.openEncounter(encounter))

        XCTAssertEqual(store.state.simpleAdventure.encounter.building, encounter)
        XCTAssertEqual(store.state.simpleAdventure.encounter.navigationTitleOverride, "Encounter")
        XCTAssertEqual(
            store.state.referenceView.encounterReferenceContext,
            EncounterReferenceContext(building: encounter, running: nil)
        )
    }

    func testOpenEncounterUsesCampaignBrowserInCampaignBrowserMode() async throws {
        let encounter = Encounter(name: "Campaign encounter", combatants: [])
        let store = try await makeStore(adventureTabMode: .campaignBrowser)

        await store.send(.openEncounter(encounter))

        guard case let .encounter(detailState)? = store.state.campaignBrowse.destination else {
            XCTFail("Expected campaign browser destination to be an encounter")
            return
        }
        XCTAssertEqual(detailState.building, encounter)
        XCTAssertEqual(
            store.state.referenceView.encounterReferenceContext,
            EncounterReferenceContext(building: encounter, running: nil)
        )
    }

    func testSimpleAdventureDelegateOpensEncounterInCampaignBrowser() async throws {
        let encounter = Encounter(name: "Top level encounter", combatants: [])
        let store = try await makeStore(adventureTabMode: .simpleEncounter)

        await store.send(.simpleAdventure(.delegate(.openEncounterInCampaignBrowser(encounter))))
        await store.receive(.openEncounterInCampaignBrowser(encounter))
        XCTAssertEqual(store.state.preferences.adventureTabMode, .campaignBrowser)

        guard case let .encounter(detailState)? = store.state.campaignBrowse.destination else {
            XCTFail("Expected campaign browser destination to be an encounter")
            return
        }
        XCTAssertEqual(detailState.building, encounter)
        XCTAssertEqual(
            store.state.referenceView.encounterReferenceContext,
            EncounterReferenceContext(building: encounter, running: nil)
        )
    }

    private func makeStore(
        adventureTabMode: Preferences.AdventureTabMode
    ) async throws -> TestStoreOf<ColumnNavigationFeature> {
        let database = try await Database(path: nil)
        let uuid = UUIDGenerator.fake()
        try database.keyValueStore.put(Preferences(adventureTabMode: adventureTabMode))
        let initialState = withDependencies {
            $0.database = database
            $0.uuid = uuid
        } operation: {
            ColumnNavigationFeature.State()
        }

        let store = withDependencies {
            $0.database = database
            $0.uuid = uuid
        } operation: {
            TestStore(initialState: initialState) {
                ColumnNavigationFeature()
            } withDependencies: {
                $0.database = database
                $0.uuid = uuid
            }
        }
        store.exhaustivity = .off
        return store
    }
}
