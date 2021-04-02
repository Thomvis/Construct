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

/// Inspired by https://github.com/pointfreeco/isowords/tree/main/Tests/AppStoreSnapshotTests
class AppStoreScreenshotTests: XCTestCase {
    override class func setUp() {
        super.setUp()
//        SnapshotTesting.isRecording = true
        SnapshotTesting.diffTool = "ksdiff"
    }

    func test_iPhone_screenshot1() {
        snapshot(view: tabNavigationEncounterDetailRunning, devices: [.iPhoneXsMax, .iPhoneX])
    }

    func test_iPhone_screenshot2() {
        snapshot(view: tabNavigationCombatantDetail, devices: [.iPhoneXsMax, .iPhoneX])
    }

    func test_iPhone_screenshot4() {
        snapshot(view: tabNavigationCampaignBrowseView, devices: [.iPhoneXsMax, .iPhoneX])
    }

    func test_iPhone_screenshot5() {
        snapshot(view: tabNavigationCombatantDetailMage, devices: [.iPhoneXsMax, .iPhoneX], colorScheme: .dark)
    }

    func test_iPhone_screenshot6() {
        snapshot(view: tabNavigationDiceRoller, devices: [.iPhoneXsMax, .iPhoneX], colorScheme: .dark)
    }

    func test_iPad_screenshot1() {
        snapshot(view: columnNavigationEncounterDetailRunning, devices: [.iPadPro11, .iPadPro10_5])
    }

    func test_iPad_screenshot2() {
        snapshot(view: columnNavigationCampaignBrowseView, devices: [.iPadPro11, .iPadPro10_5])
    }

    func test_iPad_screenshot3() {
        snapshot(view: columnNavigationEncounterDetailBuilding, devices: [.iPadPro11, .iPadPro10_5])
    }

    func test_iPad_screenshot4() {
        snapshot(view: columnNavigationDiceCalculatorSpell, devices: [.iPadPro11, .iPadPro10_5])
    }

    func test_iPad_screenshot5() {
        snapshot(view: columnNavigationCreatureEdit, devices: [.iPadPro11, .iPadPro10_5])
    }

    private func snapshot<View>(
        view: View,
        devices: [ViewImageConfig],
        colorScheme: ColorScheme = .light,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) where View: SwiftUI.View {
        for device in devices {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                assertSnapshot(
                    matching: view
                        .environment(\.applyTestWorkaroundSidebarPresentation, true)
                        .environment(\.colorScheme, colorScheme)
                        .environmentObject(Environment(window: UIWindow())),
                    as: .image(precision: 0.99, layout: .device(config: device)),
                   file: file,
                   testName: testName,
                   line: line
                )
            }
        }
    }

    var tabNavigationEncounterDetailRunning: ContentView {
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
                                    key: encounterDetailViewState.encounter.key,
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
            ),
            preferences: Preferences()
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var tabNavigationDiceRoller: ContentView {
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
            ),
            preferences: Preferences()
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var tabNavigationCombatantDetail: some View {
        var encounterDetailViewState = encounterDetailRunningEncounterDetailState
        let state = CombatantDetailViewState(
            combatant: encounterDetailViewState.encounter.combatants[1]
        )

        let store = Store<CombatantDetailViewState, CombatantDetailViewAction>(initialState: state, reducer: Reducer.empty, environment: ())
        return FakeSheetView(
            background: Color(UIColor.secondarySystemBackground),
            sheet: CombatantDetailContainerView(store: store)
        )
    }

    var tabNavigationCampaignBrowseView: ContentView {
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
            ),
            preferences: Preferences()
        )

        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var tabNavigationCombatantDetailMage: some View {
        let environment = Environment(window: UIWindow())

        let entry = try! environment.database.keyValueStore.get(
            CompendiumItemKey(type: .monster, realm: .core, identifier: "Mage")
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

                mage.resources[0].used = 1
                mage.resources[1].used = 3
                mage.resources[3].used = 1
            }
        )
        let store = Store<CombatantDetailViewState, CombatantDetailViewAction>(initialState: state, reducer: Reducer.empty, environment: ())
        return FakeSheetView(
            background: Color(UIColor.secondarySystemBackground),
            sheet: CombatantDetailContainerView(store: store)
        )
    }

    var columnNavigationEncounterDetailRunning: ContentView {
        let encounterDetailViewState = encounterDetailRunningEncounterDetailState

        let state = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    sidebar: SidebarViewState(
                        campaignNodes: [:],
                        campaignNodeIsExpanded: [:],
                        presentedScreens: [
                            .detail: .campaignBrowse(
                                CampaignBrowseTwoColumnContainerState(
                                    content: .encounter(encounterDetailViewState),
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
                                    showReferenceView: true
                                )
                            )
                        ],
                        sheet: nil
                    ),
                    diceCalculator: FloatingDiceRollerViewState(
                        hidden: true,
                        diceCalculator: DiceCalculatorState.abilityCheck(3, rollOnAppear: false, prefilledResult: 22)
                    )
                )
            ),
            preferences: Preferences()
        )
        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var encounterDetailRunningEncounterDetailState: EncounterDetailViewState {
        var encounter = SampleEncounter.createEncounter(with: Environment(window: UIWindow()))
        encounter.name = "The King's Crypt"
        // Mummy
        apply(&encounter.combatants[0]) { mummy in
            mummy.initiative = 12
        }
        // Giant-Spider 1
        apply(&encounter.combatants[1]) { spider in
            spider.initiative = 8
            spider.hp?.current = 16

        }
        // Giant-Spider 2
        apply(&encounter.combatants[2]) { spider in
            spider.initiative = 8
        }
        // Ennan
        apply(&encounter.combatants[3]) { ennan in
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
        apply(&encounter.combatants[4]) { willow in
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
        apply(&encounter.combatants[5]) { umun in
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
        apply(&encounter.combatants[6]) { sarovin in
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
            turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants.elements[1].id),
            log: [
                RunningEncounterEvent(
                    id: UUID().tagged(),
                    turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants.elements[3].id),
                    combatantEvent: RunningEncounterEvent.CombatantEvent(
                        target: RunningEncounterEvent.CombatantReference(id: encounter.combatants.elements[1].id, name: "Giant Spider", discriminator: 1),
                        source: RunningEncounterEvent.CombatantReference(id: encounter.combatants.elements[3].id, name: "Ennan Yarfall", discriminator: nil),
                        effect: RunningEncounterEvent.CombatantEvent.Effect(currentHp: -4)
                    )
                ),
                RunningEncounterEvent(
                    id: UUID().tagged(),
                    turn: RunningEncounter.Turn(round: 1, combatantId: encounter.combatants.elements[0].id),
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
            editMode: false,
            selection: Set(),
            combatantDetailReferenceItemRequest: nil,
            addCombatantReferenceItemRequest: nil
        )
    }

    var columnNavigationEncounterDetailBuilding: ContentView {
        let environment = Environment(window: UIWindow())
        var encounter = SampleEncounter.createEncounter(with: Environment(window: UIWindow()))
        encounter.combatants.remove(at: 0)

        let state = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    sidebar: SidebarViewState(
                        campaignNodes: [:],
                        campaignNodeIsExpanded: [:],
                        presentedScreens: [
                            .detail: .campaignBrowse(
                                CampaignBrowseTwoColumnContainerState(
                                    content: .encounter(
                                        EncounterDetailViewState(
                                            building: encounter,
                                            running: nil,
                                            resumableRunningEncounters: .initial,
                                            sheet: nil,
                                            popover: nil,
                                            editMode: false,
                                            selection: Set(),
                                            combatantDetailReferenceItemRequest: nil,
                                            addCombatantReferenceItemRequest: nil
                                        )
                                    ),
                                    referenceView: ReferenceViewState(
                                        items: IdentifiedArray(arrayLiteral:
                                            ReferenceViewState.Item(
                                                id: UUID().tagged(),
                                                title: nil,
                                                state: ReferenceItemViewState(
                                                    content: .addCombatant(
                                                        ReferenceItemViewState.Content.AddCombatant(
                                                            addCombatantState: AddCombatantState(
                                                                compendiumState: apply(CompendiumIndexState(
                                                                    title: "Monsters",
                                                                    properties: .secondary,
                                                                    results: .initial
                                                            )) { state in
                                                                state.results.input.order = .monsterChallengeRating
                                                                let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                                                                let filters = CompendiumIndexState.Query.Filters(types: [.monster], minMonsterChallengeRating: Fraction(integer: 4), maxMonsterChallengeRating: nil)
                                                                ViewStore(store).send(.query(.onFiltersDidChange(filters), debounce: false))
                                                                let entry = ViewStore(store).state.results.value!.first!
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
                                    showReferenceView: true
                                )
                            )
                        ],
                        sheet: nil
                    ),
                    diceCalculator: FloatingDiceRollerViewState(
                        hidden: true,
                        diceCalculator: DiceCalculatorState.abilityCheck(3, rollOnAppear: false, prefilledResult: 22)
                    )
                )
            ),
            preferences: Preferences()
        )
        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var columnNavigationCampaignBrowseView: ContentView {
        let environment = Environment(window: UIWindow())

        let state = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    sidebar: SidebarViewState(
                        campaignNodes: [:],
                        campaignNodeIsExpanded: [:],
                        presentedScreens: [
                            .detail: .campaignBrowse(
                                CampaignBrowseTwoColumnContainerState(
                                    content: .browse(
                                        campaignBrowseViewState
                                    ),
                                    referenceView: ReferenceViewState(
                                        items: IdentifiedArray(arrayLiteral:
                                            ReferenceViewState.Item(
                                                id: UUID().tagged(),
                                                title: nil,
                                                state: ReferenceItemViewState(
                                                    content: .home(
                                                        ReferenceItemViewState.Content.Home(
                                                            presentedScreens: [
                                                                .nextInStack: .compendium(
                                                                    apply(CompendiumIndexState(
                                                                            title: "Monsters",
                                                                            properties: .secondary,
                                                                            results: .initial
                                                                    )) { state in
                                                                        let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)
                                                                        ViewStore(store).send(.query(.onTextDidChange("Dragon"), debounce: false))
                                                                        state = ViewStore(store).state
                                                                    }
                                                                )
                                                            ]
                                                        )
                                                    )
                                                )
                                            ),
                                            ReferenceViewState.Item(
                                                id: UUID().tagged(),
                                                title: "Kobold - Compendium",
                                                state: ReferenceItemViewState(
                                                    content: .home(ReferenceItemViewState.Content.Home())
                                                )
                                            ),
                                            ReferenceViewState.Item(
                                                id: UUID().tagged(),
                                                title: "Light - Compendium",
                                                state: ReferenceItemViewState(
                                                    content: .home(ReferenceItemViewState.Content.Home())
                                                )
                                           )
                                        )
                                    ),
                                    showReferenceView: true
                                )
                            )
                        ],
                        sheet: nil
                    ),
                    diceCalculator: FloatingDiceRollerViewState(hidden: true, diceCalculator: DiceCalculatorState.nullInstance)
                )
            ),
            preferences: Preferences()
        )
        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
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

    var columnNavigationDiceCalculatorSpell: ContentView {
        let environment = Environment(window: UIWindow())

        let state = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    sidebar: SidebarViewState(
                        campaignNodes: [:],
                        campaignNodeIsExpanded: [:],
                        presentedScreens: [
                            .detail: .compendium(apply(CompendiumIndexState(
                                title: "Spells",
                                properties: .secondary,
                                results: .initial(type: .spell)
                        )) { state in
                            let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)

                            ViewStore(store).send(.query(.onTextDidChange(""), debounce: false))
                            state = ViewStore(store).state

                            let fireballSpell = state.results.value!.first(where: { $0.item.title == "Fireball" })!
                            state.scrollTo = fireballSpell.key
                            state.detailScreen = .itemDetail(CompendiumEntryDetailViewState(entry: fireballSpell))
                        })],
                        sheet: nil
                    ),
                    diceCalculator: FloatingDiceRollerViewState(
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
            ),
            preferences: Preferences()
        )
        let store = Store<AppState, AppState.Action>(initialState: state, reducer: Reducer.empty, environment: ())
        return ContentView(store: store)
    }

    var columnNavigationCreatureEdit: some View {
        let environment = Environment(window: UIWindow())

        let encounter = SampleEncounter.createEncounter(with: Environment(window: UIWindow()))

        let backgroundState = AppState(
            navigation: .column(
                ColumnNavigationViewState(
                    sidebar: SidebarViewState(
                        campaignNodes: [:],
                        campaignNodeIsExpanded: [:],
                        presentedScreens: [
                            .detail: .compendium(apply(CompendiumIndexState(
                                title: "Monsters",
                                properties: .secondary,
                                results: .initial(type: .monster)
                        )) { state in
                            let store = Store(initialState: state, reducer: CompendiumIndexState.reducer, environment: environment)

                            ViewStore(store).send(.query(.onTextDidChange(""), debounce: false))
                            state = ViewStore(store).state
                        })],
                        sheet: nil
                    ),
                    diceCalculator: FloatingDiceRollerViewState(
                        hidden: true,
                        diceCalculator: DiceCalculatorState.nullInstance
                    )
                )
            ),
            preferences: Preferences()
        )
        let backgroundStore = Store<AppState, AppState.Action>(initialState: backgroundState, reducer: Reducer.empty, environment: ())
        let backgroundView = ContentView(store: backgroundStore)

        let sheetView = SheetNavigationContainer {
            CreatureEditView(
                store: Store(
                    initialState: CreatureEditViewState(
                        edit: encounter.combatants[3].definition as! AdHocCombatantDefinition
                    ),
                    reducer: Reducer.empty,
                    environment: ()
                )
            )
        }

        return FakeSheetView(background: backgroundView, sheet: sheetView)
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

                Elevated(content: sheet)
                    .navigationViewStyle(StackNavigationViewStyle())
                    .frame(width: 700, height: 750)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 50)
            }
            .ignoresSafeArea()
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
