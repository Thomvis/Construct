//
//  AppStoreScreenshotTests.swift
//  UnitTests
//
//  Created by Thomas Visser on 01/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import ComposableArchitecture
@testable import Construct
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
import WebKit
import Helpers
import DiceRollerFeature
import Dice
import GameModels
import Persistence
import PersistenceTestSupport
import Compendium

/// Inspired by https://github.com/pointfreeco/isowords/tree/main/Tests/AppStoreSnapshotTests
@available(iOS 16.0, *)
class AppStoreScreenshotTests: XCTestCase {
    static let phones: [(String, ViewImageConfig)] = [
        ("iPhone65", apply(.iPhoneXsMax) { $0.traits = UITraitCollection(traitsFrom: [$0.traits, .init(displayScale: 3)]) }),
        ("iPhone55", apply(.iPhone8Plus) { $0.traits = UITraitCollection(traitsFrom: [$0.traits, .init(displayScale: 3)]) })
    ]

    static let pads: [(String, ViewImageConfig)] = [
        ("iPadPro129_4th_gen", .iPadPro12_9_4th_gen),
        ("iPadPro129_3rd_gen", .iPadPro12_9)
    ]

    var environment: Construct.Environment!

    override class func setUp() {
        super.setUp()
//        SnapshotTesting.isRecording = true
        SnapshotTesting.diffTool = "ksdiff"

        // Workaround for white unselected item icons in the tab bar
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray2
        // Workaround for transparent tab bar
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
    }

    override func setUp() async throws {
        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))

        environment = try! await Environment.live(
            database: db,
            mainQueue: DispatchQueue.immediate.eraseToAnyScheduler(),
            backgroundQueue: DispatchQueue.immediate.eraseToAnyScheduler()
        )
    }

    func test_iPhone_screenshot1() {
        snapshot(view: tabNavigationEncounterDetailRunning, devices: Self.phones)
    }

    func test_iPhone_screenshot2() {
        snapshot(view: tabNavigationCombatantDetail, devices: Self.phones)
    }

    @MainActor
    func test_iPhone_screenshot3() async {
        await snapshot(view: tabNavigationCompendiumIndex, devices: Self.phones)
    }

    func test_iPhone_screenshot4() {
        snapshot(view: tabNavigationCampaignBrowseView, devices: Self.phones)
    }

    func test_iPhone_screenshot5() {
        snapshot(view: tabNavigationCombatantDetailMage, devices: Self.phones, colorScheme: .dark)
    }

    func test_iPhone_screenshot6() {
        snapshot(view: tabNavigationDiceRoller, devices: Self.phones, colorScheme: .dark)
    }

    func test_iPad_screenshot1() {
        snapshot(view: columnNavigationEncounterDetailRunning, devices: Self.pads)
    }

    @MainActor
    func test_iPad_screenshot2() async {
        await snapshot(view: columnNavigationCampaignBrowseView, devices: Self.pads)
    }

    @MainActor
    func test_iPad_screenshot3() async {
        await snapshot(view: columnNavigationEncounterDetailBuilding, devices: Self.pads)
    }

    @MainActor
    func test_iPad_screenshot4() async {
        await snapshot(view: columnNavigationDiceCalculatorSpell, devices: Self.pads)
    }

    @MainActor
    func test_iPad_screenshot5() async {
        await snapshot(view: columnNavigationCreatureEdit, devices: Self.pads)
    }

    private func snapshot<View>(
        view: View,
        devices: [(String, ViewImageConfig)],
        colorScheme: ColorScheme = .light,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) where View: SwiftUI.View {
        for (name, device) in devices {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                assertSnapshot(
                    matching: FakeDeviceScreenView(imageConfig: device, content: view)
                        .environment(\.colorScheme, colorScheme)
                        .environmentObject(environment),
                    as: .imageAfterDelay(perceptualPrecision: 0.96, layout: .device(config: device), traits: device.traits),
                    named: name,
                    file: file,
                    testName: testName,
                    line: line
                )
            }
        }
    }

    var tabNavigationEncounterDetailRunning: ConstructView {
        let encounterDetailViewState = encounterDetailRunningEncounterDetailState

        let state = AppState(
            navigation: .tab(
                TabNavigationViewState(
                    selectedTab: .campaign,
                    campaignBrowser: CampaignBrowseViewState(
                        node: CampaignNode.root,
                        mode: .browse,
                        items: Async(result: .success([
                            CampaignNode(
                                id: UUID().tagged(),
                                title: "",
                                contents: CampaignNode.Contents(
                                    key: encounterDetailViewState.encounter.key.rawValue,
                                    type: .encounter
                                ),
                                special: nil,
                                parentKeyPrefix: nil
                            )
                        ])),
                        showSettingsButton: false,
                        presentedScreens: [
                            .nextInStack: .encounter(encounterDetailViewState)
                        ]),
                    compendium: CompendiumIndexState.nullInstance,
                    diceRoller: DiceRollerViewState.nullInstance
                )
            )
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return ConstructView(env: environment, store: store)
    }

    var tabNavigationDiceRoller: ConstructView {
        let state = AppState(
            navigation: .tab(
                TabNavigationViewState(
                    selectedTab: .diceRoller,
                    campaignBrowser: .nullInstance,
                    compendium: .nullInstance,
                    diceRoller: apply(DiceRollerViewState()) { state in
                        state.calculatorState.expression = 1.d(20)+1.d(6)+2
                        state.calculatorState.previousExpressions = [1.d(20)+1.d(6)]
                    }
                )
            )
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return ConstructView(env: environment, store: store)
    }

    var tabNavigationCombatantDetail: some View {
        let encounterDetailViewState = encounterDetailRunningEncounterDetailState
        let state = CombatantDetailViewState(
            combatant: encounterDetailViewState.encounter.combatants[1]
        )

        let store = Store<CombatantDetailViewState, CombatantDetailViewAction>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return FakeSheetView(
            background: Color(UIColor.secondarySystemBackground),
            sheet: CombatantDetailContainerView(store: store)
        )
    }

    @MainActor
    var tabNavigationCompendiumIndex: ConstructView {
        get async {
            let state = AppState(
                navigation: .tab(
                    TabNavigationViewState(
                        selectedTab: .compendium,
                        campaignBrowser: CampaignBrowseViewState.nullInstance,
                        compendium: await apply(CompendiumIndexState(
                            title: CompendiumItemType.monster.localizedScreenDisplayName,
                            properties: .init(showImport: false, showAdd: true, typeRestriction: nil),
                            results: .initial
                        )) { state in
                            let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                            await ViewStore(store).send(.query(.onTextDidChange("Dragon"))).finish()
                            state = ViewStore(store).state
                        },
                        diceRoller: DiceRollerViewState.nullInstance
                    )
                )
            )

            let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
            return ConstructView(env: environment, store: store)
        }
    }

    var tabNavigationCampaignBrowseView: ConstructView {
        let campaignBrowseViewState = self.campaignBrowseViewState
        let state = AppState(
            navigation: .tab(
                TabNavigationViewState(
                    selectedTab: .campaign,
                    campaignBrowser: CampaignBrowseViewState(
                        node: CampaignNode.root,
                        mode: .browse,
                        items: Async(result: .success([
                            campaignBrowseViewState.node
                        ])),
                        showSettingsButton: false,
                        presentedScreens: [
                            .nextInStack: .campaignBrowse(campaignBrowseViewState)
                        ]
                    ),
                    compendium: .nullInstance,
                    diceRoller: DiceRollerViewState.nullInstance
                )
            )
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return ConstructView(env: environment, store: store)
    }

    var tabNavigationCombatantDetailMage: some View {
        let entry = try! environment.database.keyValueStore.get(
            CompendiumItemKey(type: .monster, realm: .init(CompendiumRealm.core.id), identifier: "Mage")
        )

        let state = CombatantDetailViewState(
            combatant: apply(Combatant(compendiumCombatant: entry?.item as! CompendiumCombatant)) { mage in
                mage.initiative = 17
                mage.hp?.current = 32

                mage.tags.append(
                    CombatantTag(
                        id: UUID().tagged(),
                        definition: CombatantTagDefinition.all.first(where: { $0.name == "Concentrating" })!
                    )
                )

                mage.resources[position: 0].used = 1
                mage.resources[position: 1].used = 3
                mage.resources[position: 3].used = 1
            }
        )
        let store = Store<CombatantDetailViewState, CombatantDetailViewAction>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return FakeSheetView(
            background: Color(UIColor.secondarySystemBackground),
            sheet: CombatantDetailContainerView(store: store)
        )
    }

    var columnNavigationEncounterDetailRunning: ConstructView {
        let encounterDetailViewState = encounterDetailRunningEncounterDetailState

        let state = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    campaignBrowse: CampaignBrowseViewState(
                        node: CampaignNode.root,
                        mode: .browse,
                        items: Async(result: .success([
                            CampaignNode(
                                id: UUID().tagged(),
                                title: "",
                                contents: CampaignNode.Contents(
                                    key: encounterDetailViewState.encounter.key.rawValue,
                                    type: .encounter
                                ),
                                special: nil,
                                parentKeyPrefix: nil
                            )
                        ])),
                        showSettingsButton: true,
                        presentedScreens: [
                            .nextInStack: .encounter(encounterDetailViewState)
                        ]
                    ),
                    referenceView: ReferenceViewState(
                        items: IdentifiedArray(arrayLiteral:
                            ReferenceViewState.Item(
                                id: UUID().tagged(),
                                title: nil,
                                state: ReferenceItemViewState(
                                    content: .combatantDetail(
                                        ReferenceItemViewState.Content.CombatantDetail(
                                            encounter: encounterDetailViewState.running!.current,
                                            selectedCombatantId: encounterDetailViewState.encounter.combatants.elements[1].id,
                                            runningEncounter: encounterDetailViewState.running
                                        ))
                                )
                            )
                        )
                    ),
                    diceCalculator: FloatingDiceRollerViewState(
                        hidden: true,
                        diceCalculator: DiceCalculatorState.abilityCheck(3, rollOnAppear: false, prefilledResult: 22)
                    )
                )
            )
        )
        let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
        return ConstructView(env: environment, store: store)
    }

    var encounterDetailRunningEncounterDetailState: EncounterDetailViewState {
        var encounter = SampleEncounter.createEncounter(with: environment)
        encounter.name = "The King's Crypt"
        // Mummy
        apply(&encounter.combatants[position: 0]) { mummy in
            mummy.initiative = 12
        }
        // Giant-Spider 1
        apply(&encounter.combatants[position: 1]) { spider in
            spider.initiative = 8
            spider.hp?.current = 16

        }
        // Giant-Spider 2
        apply(&encounter.combatants[position: 2]) { spider in
            spider.initiative = 8
        }
        // Ennan
        apply(&encounter.combatants[position: 3]) { ennan in
            ennan.initiative = 20
            ennan.hp?.current = 16
            ennan.tags.append(
                CombatantTag(
                    id: UUID().tagged(),
                    definition: CombatantTagDefinition.all.first(where: { $0.name == "Blessed" })!,
                    note: nil,
                    duration: nil,
                    addedIn: nil,
                    sourceCombatantId: nil
                )
            )
        }
        apply(&encounter.combatants[position: 4]) { willow in
            willow.initiative = 23
            willow.tags.append(
                CombatantTag(
                    id: UUID().tagged(),
                    definition: CombatantTagDefinition.all.first(where: { $0.name == "Hidden" })!,
                    note: "DC 17",
                    duration: nil,
                    addedIn: nil,
                    sourceCombatantId: nil
                )
            )
            willow.tags.append(
                CombatantTag(
                    id: UUID().tagged(),
                    definition: CombatantTagDefinition.all.first(where: { $0.name == "Blessed" })!,
                    note: nil,
                    duration: nil,
                    addedIn: nil,
                    sourceCombatantId: nil
                )
            )
        }
        apply(&encounter.combatants[position: 5]) { umun in
            umun.initiative = 7
            umun.tags.append(
                CombatantTag(
                    id: UUID().tagged(),
                    definition: CombatantTagDefinition.all.first(where: { $0.name == "Blessed" })!,
                    note: nil,
                    duration: nil,
                    addedIn: nil,
                    sourceCombatantId: nil
                )
            )
        }
        apply(&encounter.combatants[position: 6]) { sarovin in
            sarovin.initiative = 11
            sarovin.tags.append(
                CombatantTag(
                    id: UUID().tagged(),
                    definition: CombatantTagDefinition.all.first(where: { $0.name == "Restrained" })!,
                    note: nil,
                    duration: nil,
                    addedIn: nil,
                    sourceCombatantId: nil
                )
            )
        }

        let runningEncounter = RunningEncounter(
            id: UUID().tagged(),
            base: encounter,
            current: encounter,
            turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants[position: 1].id),
            log: [
                RunningEncounterEvent(
                    id: UUID().tagged(),
                    turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants[position: 3].id),
                    combatantEvent: RunningEncounterEvent.CombatantEvent(
                        target: RunningEncounterEvent.CombatantReference(id: encounter.combatants[position: 1].id, name: "Giant Spider", discriminator: 1),
                        source: RunningEncounterEvent.CombatantReference(id: encounter.combatants.elements[3].id, name: "Ennan Yarfall", discriminator: nil),
                        effect: RunningEncounterEvent.CombatantEvent.Effect(currentHp: -4)
                    )
                ),
                RunningEncounterEvent(
                    id: UUID().tagged(),
                    turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants[position: 0].id),
                    combatantEvent: RunningEncounterEvent.CombatantEvent(
                        target: RunningEncounterEvent.CombatantReference(id: encounter.combatants.elements[3].id, name: "Ennan Yarfall", discriminator: 1),
                        source: RunningEncounterEvent.CombatantReference(id: encounter.combatants.elements[0].id, name: "Mummy", discriminator: nil),
                        effect: RunningEncounterEvent.CombatantEvent.Effect(currentHp: -11)
                    )
                )
            ]
        )

        return EncounterDetailViewState(
            building: encounter,
            running: runningEncounter,
            resumableRunningEncounters: .initial,
            sheet: nil,
            popover: nil,
            editMode: .inactive,
            selection: Set()
        )
    }

    @MainActor
    var columnNavigationEncounterDetailBuilding: ConstructView {
        get async {
            var encounter = SampleEncounter.createEncounter(with: environment)
            encounter.combatants.remove(at: 0)

            let state = AppState(
                navigation: .column(
                    ColumnNavigationViewState(
                        campaignBrowse: CampaignBrowseViewState(
                            node: CampaignNode.root,
                            mode: .browse,
                            items: Async(result: .success([
                                CampaignNode(
                                    id: UUID().tagged(),
                                    title: "",
                                    contents: CampaignNode.Contents(
                                        key: encounter.key.rawValue,
                                        type: .encounter
                                    ),
                                    special: nil,
                                    parentKeyPrefix: nil
                                )
                            ])),
                            showSettingsButton: true,
                            presentedScreens: [
                                .nextInStack: .encounter(EncounterDetailViewState(
                                    building: encounter,
                                    running: nil,
                                    resumableRunningEncounters: .initial,
                                    sheet: nil,
                                    popover: nil,
                                    editMode: .inactive,
                                    selection: Set()
                                ))
                            ]
                        ),
                        referenceView: ReferenceViewState(
                            items: IdentifiedArray(
                                arrayLiteral: ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: nil,
                                    state: ReferenceItemViewState(
                                        content: .addCombatant(
                                            ReferenceItemViewState.Content.AddCombatant(
                                                addCombatantState: AddCombatantState(
                                                    compendiumState: await apply(CompendiumIndexState(
                                                        title: "Monsters",
                                                        properties: .init(showImport: false, showAdd: true, typeRestriction: nil),
                                                        results: .initial
                                                    )) { @MainActor state in
                                                        state.results.input.order = .monsterChallengeRating
                                                        let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                                                        let filters = CompendiumFilters(types: [.monster], minMonsterChallengeRating: Fraction(integer: 4))
                                                        await ViewStore(store).send(.query(.onFiltersDidChange(filters))).finish()
                                                        let entry = ViewStore(store).state.results.entries!.first!
                                                        ViewStore(store).send(.setNextScreen(.itemDetail(CompendiumEntryDetailViewState(entry: entry))))
                                                        state = ViewStore(store).state
                                                    },
                                                    encounter: encounter
                                                ),
                                                context: ReferenceContext(encounterDetailView: nil, openCompendiumEntries: [])
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        diceCalculator: FloatingDiceRollerViewState(
                            hidden: true,
                            diceCalculator: DiceCalculatorState.abilityCheck(3, rollOnAppear: false, prefilledResult: 22)
                        )
                    )
                )
            )
            let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
            return ConstructView(env: environment, store: store)
        }
    }

    @MainActor
    var columnNavigationCampaignBrowseView: ConstructView {
        get async {
            let state = AppState(
                navigation: .column(
                    ColumnNavigationViewState(
                        campaignBrowse: campaignBrowseViewState,
                        referenceView: ReferenceViewState(
                            items: IdentifiedArray(
                                arrayLiteral: ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: nil,
                                    state: ReferenceItemViewState(
                                        content: .compendium(
                                            ReferenceItemViewState.Content.Compendium(
                                                compendium: await apply(CompendiumIndexState(
                                                    title: CompendiumItemType.monster.localizedScreenDisplayName,
                                                    properties: .init(showImport: false, showAdd: true, typeRestriction: nil),
                                                    results: .initial
                                                )) { state in
                                                    let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                                                    await ViewStore(store).send(.query(.onTextDidChange("Dragon"))).finish()
                                                    state = ViewStore(store).state
                                                }
                                            )
                                        )
                                    )
                                ),
                                ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: "Kobold - Compendium",
                                    state: ReferenceItemViewState(
                                        content: .compendium(ReferenceItemViewState.Content.Compendium())
                                    )
                                ),
                                ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: "Light - Compendium",
                                    state: ReferenceItemViewState(
                                        content: .compendium(ReferenceItemViewState.Content.Compendium())
                                    )
                                )
                            )
                        ),
                        diceCalculator: FloatingDiceRollerViewState(hidden: true, diceCalculator: DiceCalculatorState.nullInstance)
                    )
                )
            )
            let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
            return ConstructView(env: environment, store: store)
        }
    }

    var campaignBrowseViewState: CampaignBrowseViewState {
        CampaignBrowseViewState(
            node: CampaignNode(
                id: UUID().tagged(),
                title: "Crowflat Keep",
                contents: nil,
                special: nil,
                parentKeyPrefix: nil
            ),
            mode: .browse,
            items: Async(result: .success([
                CampaignNode(
                    id: UUID().tagged(),
                    title: "1. Ambush",
                    contents: CampaignNode.Contents(key: "", type: .encounter),
                    special: nil,
                    parentKeyPrefix: nil
                ),
                CampaignNode(
                    id: UUID().tagged(),
                    title: "2. Entrance",
                    contents: CampaignNode.Contents(key: "", type: .encounter),
                    special: nil,
                    parentKeyPrefix: nil
                ),
                CampaignNode(
                    id: UUID().tagged(),
                    title: "3. Eyes in the Night",
                    contents: CampaignNode.Contents(key: "", type: .encounter),
                    special: nil,
                    parentKeyPrefix: nil
                ),
                CampaignNode(
                    id: UUID().tagged(),
                    title: "Random Encounters",
                    contents: nil,
                    special: nil,
                    parentKeyPrefix: nil
                )
            ])),
            showSettingsButton: false,
            sheet: nil,
            presentedScreens: [:]
        )
    }

    @MainActor
    var columnNavigationDiceCalculatorSpell: ConstructView {
        get async {
            let state = AppState(
                navigation: .column(
                    ColumnNavigationViewState(
                        campaignBrowse: campaignBrowseViewState,
                        referenceView: ReferenceViewState(
                            items: IdentifiedArray(
                                arrayLiteral:ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: nil,
                                    state: ReferenceItemViewState(
                                        content: .compendium(
                                            ReferenceItemViewState.Content.Compendium(
                                                compendium: await apply(CompendiumIndexState(
                                                    title: CompendiumItemType.spell.localizedScreenDisplayName,
                                                    properties: .init(showImport: false, showAdd: true, typeRestriction: nil),
                                                    results: .initial(type: .spell)
                                                )) { @MainActor state in
                                                    let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)

                                                    await ViewStore(store).send(.results(.result(.reload(.all)))).finish()
                                                    state = ViewStore(store).state

                                                    let fireballSpell = state.results.entries!.first(where: { $0.item.title == "Fireball" })!
                                                    state.scrollTo = fireballSpell.key
                                                    state.nextScreen = .itemDetail(CompendiumEntryDetailViewState(entry: fireballSpell))
                                                }
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        diceCalculator:  FloatingDiceRollerViewState(
                            hidden: false,
                            diceCalculator: DiceCalculatorState(
                                displayOutcomeExternally: false,
                                rollOnAppear: false,
                                expression: 8.d(6),
                                result: RolledDiceExpression.dice(
                                    die: Die(sides: 6),
                                    values: [5, 4, 6, 6, 2, 4, 1, 5]
                                ),
                                intermediaryResult: nil,
                                mode: .rollingExpression,
                                showDice: false,
                                previousExpressions: [],
                                entryContext: DiceCalculatorState.EntryContext(
                                    color: nil,
                                    subtract: false
                                )
                            )
                        )
                    )
                )
            )

            let store = Store<AppState, AppState.Action>(initialState: state, reducer: AnyReducer.empty, environment: ())
            return ConstructView(env: environment, store: store)
        }
    }

    @MainActor
    var columnNavigationCreatureEdit: some View {
        get async {
            let encounter = SampleEncounter.createEncounter(with: environment)

            let backgroundState = AppState(
                navigation: .column(
                    ColumnNavigationViewState(
                        campaignBrowse: campaignBrowseViewState,
                        referenceView: ReferenceViewState(
                            items: IdentifiedArray(
                                arrayLiteral: ReferenceViewState.Item(
                                    id: UUID().tagged(),
                                    title: nil,
                                    state: ReferenceItemViewState(
                                        content: .compendium(
                                            ReferenceItemViewState.Content.Compendium(
                                                compendium: await apply(CompendiumIndexState(
                                                    title: CompendiumItemType.monster.localizedScreenDisplayName,
                                                    properties: .init(showImport: false, showAdd: true, typeRestriction: nil),
                                                    results: .initial
                                                )) { state in
                                                    let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                                                    await ViewStore(store).send(.query(.onTextDidChange("Dragon"))).finish()
                                                    state = ViewStore(store).state
                                                }
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        diceCalculator: FloatingDiceRollerViewState(
                            hidden: true,
                            diceCalculator: DiceCalculatorState.nullInstance
                        )
                    )
                )
            )
            let backgroundStore = Store<AppState, AppState.Action>(initialState: backgroundState, reducer: AnyReducer.empty, environment: ())
            let backgroundView = ConstructView(env: environment, store: backgroundStore)

            let sheetView = SheetNavigationContainer {
                CreatureEditView(
                    store: Store(
                        initialState: CreatureEditViewState(
                            edit: encounter.combatants[3].definition as! AdHocCombatantDefinition
                        ),
                        reducer: AnyReducer.empty,
                        environment: ()
                    )
                )
            }

            return FakeSheetView(background: backgroundView, sheet: sheetView)
        }
    }
}

/// Fakes a sheet presentation because actual sheet presentation is hard to snapshot
/// It requires a delay and snapshotting the view inside the key UIWindow
/// This view has its limitations:
/// - the navigation bar & background color of the sheet are not changed
///   as they do in an actual sheet
struct FakeSheetView<Background, Modal>: View where Background: View, Modal: View {
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass

    let background: Background
    let sheet: Modal

    var body: some View {
        if horizontalSizeClass == .regular {
            ZStack {
                background.accentColor(Color(UIColor.systemGray))

                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                Elevated(content: sheet)
                    .navigationViewStyle(StackNavigationViewStyle())
                    .frame(width: 700, height: 750)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 50)
                    .ignoresSafeArea()
            }
        } else {
            ZStack {
                Color.black.ignoresSafeArea(.all, edges: .all)

                background
                    .cornerRadius(8)
                    .opacity(0.8)
                    .padding(EdgeInsets(top: 10, leading: 18, bottom: 0, trailing: 18))

                Elevated(content: sheet)
                    .cornerRadius(8)
                    .padding(.top, 20)
                    .ignoresSafeArea(.all, edges: .bottom)
            }
        }
    }

    private struct Elevated<Content>: UIViewControllerRepresentable where Content: View {
        let content: Content

        func makeUIViewController(context: Context) -> ElevatedHostingController<Content> {
            ElevatedHostingController(rootView: content)
        }

        func updateUIViewController(_ uiViewController: ElevatedHostingController<Content>, context: Context) {
            uiViewController.rootView = content
        }
    }

    private final class ElevatedHostingController<Content>: UIHostingController<Content> where Content: View {
        override func overrideTraitCollection(forChild childViewController: UIViewController) -> UITraitCollection? {
            UITraitCollection(traitsFrom: [
                traitCollection,
                UITraitCollection(userInterfaceLevel: .elevated)
            ])
        }
    }
}

struct FakeDeviceScreenView<Content>: View where Content: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let imageConfig: ViewImageConfig
    let content: Content
    var statusBarColorScheme: ColorScheme? = nil

    init(imageConfig: ViewImageConfig, content: Content) {
        self.imageConfig = imageConfig
        self.content = content

        if String(describing: content.self).hasPrefix("FakeSheetView") && !isPad {
            self.statusBarColorScheme = .dark
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            content

            StatusBar(colorScheme: statusBarColorScheme ?? colorScheme, imageConfig: imageConfig)
                .ignoresSafeArea()

            if imageConfig.safeArea.bottom > 0 {
                // home indicator
                Rectangle()
                    .foregroundColor(Color(UIColor.label))
                    .opacity(0.80)
                    .frame(width: isPad ? 350 : 140, height: 6)
                    .cornerRadius(3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, isPad ? 6 : 4)
                    .ignoresSafeArea()
            }
        }
    }

    var isPad: Bool {
        imageConfig.traits.userInterfaceIdiom == .pad
    }

    struct StatusBar: View {
        let colorScheme: ColorScheme

        let imageConfig: ViewImageConfig

        var body: some View {
            Group {
                if hasNotch {
                    HStack {
                        Text("9:41")

                        Spacer()

                        Text("\(Image(systemName: "chart.bar.fill")) \(Image(systemName: "wifi")) \(Image(systemName: "battery.100"))")
                    }
                } else if isPad {
                    HStack {
                        Text("9:41")

                        Spacer()

                        Text("\(Image(systemName: "wifi")) 100% \(Image(systemName: "battery.100"))")
                    }
                } else {
                    HStack {
                        Text("\(Image(systemName: "chart.bar.fill")) \(Image(systemName: "wifi"))")

                        Spacer()

                        Text("\(Image(systemName: "battery.100"))")
                    }.overlay(Text("9:41"))
                }

            }
            .font(Font.system(size: isPad ? 12 : 14).monospacedDigit().bold())
            .foregroundColor(self.colorScheme == .dark ? .white : .black)
            .padding(
                isPad
                    ? EdgeInsets(top: 16, leading: 24, bottom: 0, trailing: 24)
                    : EdgeInsets(top: 18, leading: 25, bottom: 0, trailing: 22)
            )
            .ignoresSafeArea()
        }

        var hasNotch: Bool {
            imageConfig.safeArea.top > 20
        }

        var isPad: Bool {
            imageConfig.traits.userInterfaceIdiom == .pad
        }
    }
}

extension ViewImageConfig {
    public static let iPadPro12_9_4th_gen = ViewImageConfig.iPadPro12_9_4th_gen(.landscape)

      public static func iPadPro12_9_4th_gen(_ orientation: Orientation) -> ViewImageConfig {
        switch orientation {
        case .landscape:
          return ViewImageConfig.iPadPro12_9_4th_gen(.landscape(splitView: .full))
        case .portrait:
          return ViewImageConfig.iPadPro12_9_4th_gen(.portrait(splitView: .full))
        }
      }

      public static func iPadPro12_9_4th_gen(_ orientation: TabletOrientation) -> ViewImageConfig {
        var base = Self.iPadPro12_9(orientation)
        base.safeArea = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        return base
      }
}

// Everything below this point is copied and adapted from https://github.com/pointfreeco/swift-snapshot-testing
// to introduce a small delay before snapshotting. This fixes blank NavigationViews.

extension Snapshotting where Value: SwiftUI.View, Format == UIImage {
    static func imageAfterDelay(
        drawHierarchyInKeyWindow: Bool = false,
        perceptualPrecision: Float = 1,
        layout: SwiftUISnapshotLayout = .sizeThatFits,
        traits: UITraitCollection = .init()
    )
    -> Snapshotting {
        let config: ViewImageConfig

        switch layout {
#if os(iOS) || os(tvOS)
        case let .device(config: deviceConfig):
            config = deviceConfig
#endif
        case .sizeThatFits:
            config = .init(safeArea: .zero, size: nil, traits: traits)
        case let .fixed(width: width, height: height):
            let size = CGSize(width: width, height: height)
            config = .init(safeArea: .zero, size: size, traits: traits)
        }

        return SimplySnapshotting.image(perceptualPrecision: perceptualPrecision, scale: traits.displayScale).asyncPullback { view in
            var config = config

            let controller: UIViewController

            if config.size != nil {
                controller = UIHostingController.init(
                    rootView: view
                )
            } else {
                let hostingController = UIHostingController.init(rootView: view)

                let maxSize = CGSize(width: 0.0, height: 0.0)
                config.size = hostingController.sizeThatFits(in: maxSize)

                controller = hostingController
            }

            return snapshotView(
                config: config,
                drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
                traits: traits,
                view: controller.view,
                viewController: controller
            )
        }
    }
}

private let offscreen: CGFloat = 10_000

func snapshotView(
    config: ViewImageConfig,
    drawHierarchyInKeyWindow: Bool,
    traits: UITraitCollection,
    view: UIView,
    viewController: UIViewController
) -> SnapshotTesting.Async<UIImage> {
    
    let initialFrame = view.frame
    let dispose = prepareView(
        config: config,
        drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
        traits: traits,
        view: view,
        viewController: viewController
    )

    // work-around to ensure the view is updated in some cases
    // e.g. the CompendiumSearchModifier would not display the text from the state
    viewController.view.window?.rootViewController?.beginAppearanceTransition(false, animated: false)
    viewController.view.window?.rootViewController?.endAppearanceTransition()
    viewController.view.window?.rootViewController?.beginAppearanceTransition(true, animated: false)
    viewController.view.window?.rootViewController?.endAppearanceTransition()


    // NB: Avoid safe area influence.
    if config.safeArea == .zero { view.frame.origin = .init(x: offscreen, y: offscreen) }

    return (view.snapshot ?? Async { callback in
        let e = XCTestExpectation()
        Task {
            try await Task.sleep(for: .milliseconds(100))
            e.fulfill()
        }
        XCTWaiter().wait(for: [e], timeout: 1)

        addImagesForRenderedViews(view).sequence().run { views in
            callback(
                renderer(bounds: view.bounds, for: traits).image { ctx in
                    if drawHierarchyInKeyWindow {
                        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
                    } else {
                        view.layer.render(in: ctx.cgContext)
                    }
                }
            )

            views.forEach { $0.removeFromSuperview() }
            view.frame = initialFrame
        }
    }).map { dispose(); return $0 }
}

func prepareView(
    config: ViewImageConfig,
    drawHierarchyInKeyWindow: Bool,
    traits: UITraitCollection,
    view: UIView,
    viewController: UIViewController
) -> () -> Void {
    let size = config.size ?? viewController.view.frame.size
    view.frame.size = size
    if view != viewController.view {
        viewController.view.bounds = view.bounds
        viewController.view.addSubview(view)
    }
    let traits = UITraitCollection(traitsFrom: [config.traits, traits])
    let window: UIWindow
    if drawHierarchyInKeyWindow {
        fatalError("'drawHierarchyInKeyWindow' not supported")
    } else {
        window = Window(
            config: .init(safeArea: config.safeArea, size: config.size ?? size, traits: traits),
            viewController: viewController
        )
    }
    let dispose = add(traits: traits, viewController: viewController, to: window)

    if size.width == 0 || size.height == 0 {
        // Try to call sizeToFit() if the view still has invalid size
        view.sizeToFit()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    return dispose
}

func addImagesForRenderedViews(_ view: UIView) -> [SnapshotTesting.Async<UIView>] {
    return view.snapshot
        .map { async in
            [
                Async { callback in
                    async.run { image in
                        let imageView = UIImageView()
                        imageView.image = image
                        imageView.frame = view.frame
#if os(macOS)
                        view.superview?.addSubview(imageView, positioned: .above, relativeTo: view)
#elseif os(iOS) || os(tvOS)
                        view.superview?.insertSubview(imageView, aboveSubview: view)
#endif
                        callback(imageView)
                    }
                }
            ]
        }
    ?? view.subviews.flatMap(addImagesForRenderedViews)
}

extension UIView {
    var snapshot: SnapshotTesting.Async<UIImage>? {
        func inWindow<T>(_ perform: () -> T) -> T {
#if os(macOS)
            let superview = self.superview
            defer { superview?.addSubview(self) }
            let window = ScaledWindow()
            window.contentView = NSView()
            window.contentView?.addSubview(self)
            window.makeKey()
#endif
            return perform()
        }

#if os(iOS) || os(macOS)
        if let wkWebView = self as? WKWebView {
            return SnapshotTesting.Async<UIImage> { callback in
                let delegate = NavigationDelegate()
                let work = {
                    if #available(iOS 11.0, macOS 10.13, *) {
                        inWindow {
                            guard wkWebView.frame.width != 0, wkWebView.frame.height != 0 else {
                                callback(UIImage())
                                return
                            }
                            wkWebView.takeSnapshot(with: nil) { image, _ in
                                _ = delegate
                                callback(image!)
                            }
                        }
                    } else {
#if os(iOS)
                        fatalError("Taking WKWebView snapshots requires iOS 11.0 or greater")
#elseif os(macOS)
                        fatalError("Taking WKWebView snapshots requires macOS 10.13 or greater")
#endif
                    }
                }

                if wkWebView.isLoading {
                    delegate.didFinish = work
                    wkWebView.navigationDelegate = delegate
                } else {
                    work()
                }
            }
        }
#endif
        return nil
    }
#if os(iOS) || os(tvOS)
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
#endif
}

private final class NavigationDelegate: NSObject, WKNavigationDelegate {
    var didFinish: () -> Void

    init(didFinish: @escaping () -> Void = {}) {
        self.didFinish = didFinish
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState") { _, _ in
            self.didFinish()
        }
    }
}

private final class Window: UIWindow {
    var config: ViewImageConfig

    init(config: ViewImageConfig, viewController: UIViewController) {
        let size = config.size ?? viewController.view.bounds.size
        self.config = config
        super.init(frame: .init(origin: .zero, size: size))

        // NB: Safe area renders inaccurately for UI{Navigation,TabBar}Controller.
        // Fixes welcome!
        if viewController is UINavigationController {
            self.frame.size.height -= self.config.safeArea.top
            self.config.safeArea.top = 0
        } else if let viewController = viewController as? UITabBarController {
            self.frame.size.height -= self.config.safeArea.bottom
            self.config.safeArea.bottom = 0
            if viewController.selectedViewController is UINavigationController {
                self.frame.size.height -= self.config.safeArea.top
                self.config.safeArea.top = 0
            }
        }
        self.isHidden = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(iOS 11.0, *)
    override var safeAreaInsets: UIEdgeInsets {
#if os(iOS)
        let removeTopInset = self.config.safeArea == .init(top: 20, left: 0, bottom: 0, right: 0)
        && self.rootViewController?.prefersStatusBarHidden ?? false
        if removeTopInset { return .zero }
#endif
        return self.config.safeArea
    }
}

func renderer(bounds: CGRect, for traits: UITraitCollection) -> UIGraphicsImageRenderer {
    let renderer: UIGraphicsImageRenderer
    if #available(iOS 11.0, tvOS 11.0, *) {
        renderer = UIGraphicsImageRenderer(bounds: bounds, format: .init(for: traits))
    } else {
        renderer = UIGraphicsImageRenderer(bounds: bounds)
    }
    return renderer
}

private func add(traits: UITraitCollection, viewController: UIViewController, to window: UIWindow) -> () -> Void {
    let rootViewController: UIViewController
    if viewController != window.rootViewController {
        rootViewController = UIViewController()
        rootViewController.view.backgroundColor = .clear
        rootViewController.view.frame = window.frame
        rootViewController.view.translatesAutoresizingMaskIntoConstraints =
        viewController.view.translatesAutoresizingMaskIntoConstraints
        rootViewController.preferredContentSize = rootViewController.view.frame.size
        viewController.view.frame = rootViewController.view.frame
        rootViewController.view.addSubview(viewController.view)
        if viewController.view.translatesAutoresizingMaskIntoConstraints {
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        } else {
            NSLayoutConstraint.activate([
                viewController.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
                viewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
                viewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
                viewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
            ])
        }
        rootViewController.addChild(viewController)
    } else {
        rootViewController = viewController
    }
    rootViewController.setOverrideTraitCollection(traits, forChild: viewController)
    viewController.didMove(toParent: rootViewController)

    window.rootViewController = rootViewController

    rootViewController.beginAppearanceTransition(true, animated: false)
    rootViewController.endAppearanceTransition()

    rootViewController.view.setNeedsLayout()
    rootViewController.view.layoutIfNeeded()

    viewController.view.setNeedsLayout()
    viewController.view.layoutIfNeeded()

    return {
        rootViewController.beginAppearanceTransition(false, animated: false)
        rootViewController.endAppearanceTransition()
        window.rootViewController = nil
    }
}

extension Array {
    func sequence<A>() -> SnapshotTesting.Async<[A]> where Element == SnapshotTesting.Async<A> {
        guard !self.isEmpty else { return SnapshotTesting.Async(value: []) }
        return SnapshotTesting.Async<[A]> { callback in
            var result = [A?](repeating: nil, count: self.count)
            result.reserveCapacity(self.count)
            var count = 0
            zip(self.indices, self).forEach { idx, async in
                async.run {
                    result[idx] = $0
                    count += 1
                    if count == self.count {
                        callback(result as! [A])
                    }
                }
            }
        }
    }
}
