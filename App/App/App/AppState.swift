//
//  AppState.swift
//  Construct
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import FirebaseCrashlytics
import SwiftUI
import Combine
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import URLRouting
import GameModels
import Persistence
import Compendium
import Sharing

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {

        var navigation: Navigation.State?
        @Presents var destination: Destination.State?
        var pendingDestinations: [Destination.State] = []

        var sceneIsActive = false

        @Shared(.entity(Preferences.key)) var preferences = Preferences()

        @Presents var crashReportingPermissionAlert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
        case onLaunch
        case navigation(Navigation.Action)

        case onHorizontalSizeClassChange(UserInterfaceSizeClass)

        case requestDestination(Destination.State)
        case destination(PresentationAction<Destination.Action>)
        case presentCrashReportingPermissionAlert

        case onReceiveCrashReportingUserPermission(CrashReporter.UserPermission)

        case onAppear

        case scene(ScenePhase)

        case onOpenURL(URL)

        case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
        
        case alert(PresentationAction<Alert>)
        
        enum Alert: Equatable {
            case send
            case dontSend
        }
    }

    @Reducer
    enum Destination {
        case welcome(WelcomeFeature)
        case defaultContentSelection(DefaultContentSelectionFeature)
    }

    @Dependency(\.appReview) var appReview
    @Dependency(\.campaignBrowser) var campaignBrowser
    @Dependency(\.crashReporter) var crashReporter
    @Dependency(\.database) var database
    @Dependency(\.diceLog) var diceLog
    @Dependency(\.idleTimer) var idleTimer
    @Dependency(\.storeManager) var storeManager

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onLaunch:
                return .merge(
                    .run { [preferences = state.preferences] send in
                        // Check Crashlytics
                        if Crashlytics.crashlytics().didCrashDuringPreviousExecution() {
                            if preferences.errorReportingEnabled == true {
                                // user consent has been given, send reports
                                crashReporter.registerUserPermission(.send)
                            }

                            await send(.presentCrashReportingPermissionAlert)
                        }
                    },
                    .run { _ in
                        storeManager.beginObservingTransactionUpdates()
                        await storeManager.checkForUnfinishedTransactions()
                    },
                    // Listen to dice rolls and forward them to the right place
                    .run { send in
                        for await (result, roll) in diceLog.rolls.values {
                            await send(.onProcessRollForDiceLog(result, roll))
                        }
                    }
                    .cancellable(id: "diceLog", cancelInFlight: true),
                    // kickstart compendium loading to prevent flicker on tab switch (not needed on iPad)
                    .send(.navigation(.tab(.compendium(.results(.result(.didShowElementAtIndex(0)))))))
                )
            case .navigation: break // handled below
            case .onHorizontalSizeClassChange(let sizeClass):
                switch (state.navigation, sizeClass) {
                case (nil, .compact):
                    state.navigation = .tab(TabNavigationFeature.State())
                case (.column(let prev), .compact):
                    state.navigation = .tab(prev.tabNavigationViewState)
                case (nil, .regular):
                    state.navigation = .column(ColumnNavigationFeature.State())
                case (.tab(let prev), .regular):
                    state.navigation = .column(prev.columnNavigationViewState)
                default:
                    break
                }
            case .requestDestination(let destination):
                precondition(!database.needsPrepareForUse)

                if state.destination == nil {
                    state.destination = destination
                } else {
                    state.pendingDestinations.append(destination)
                }
            case .destination(.dismiss):
                guard let destination = state.destination else { break }
                let isUiTesting = ProcessInfo.processInfo.environment["CONSTRUCT_UI_TESTS"] == "1"
                if case .welcome = destination, !isUiTesting {
                    state.$preferences.withLock {
                        $0.didShowWelcomeSheet = true
                        $0.dismissedDefaultContentUpdatePromptToken = defaultContentUpdateDismissalToken()
                    }
                }
                if case .defaultContentSelection = destination {
                    state.$preferences.withLock {
                        $0.dismissedDefaultContentUpdatePromptToken = defaultContentUpdateDismissalToken()
                    }
                }
                state.destination = nil

                if let next = state.pendingDestinations.first {
                    state.pendingDestinations.removeFirst()
                    return .run { send in
                        try await Task.sleep(for: .seconds(0.1))
                        await send(.requestDestination(next))
                    }
                }
            case .destination(.presented(.welcome(.delegate(.dismissWelcomeSheet)))):
                return .send(.destination(.dismiss))
            case .destination(.presented(.welcome(.delegate(.openSampleEncounter(let selection))))):
                return .run { send in
                    if let encounter = SampleEncounter.restore(
                        database: database,
                        crashReporter: crashReporter,
                        ruleset: WelcomeFeature.sampleEncounterRuleset(selection: selection)
                    ) {
                        await send(.navigation(.openEncounter(encounter)))
                    }

                    await send(.destination(.dismiss))
                }
            case .destination(.presented(.defaultContentSelection(.delegate(.applied(let appliedSelection))))):
                state.$preferences.withLock { $0.dismissedDefaultContentUpdatePromptToken = nil }
                return .run { send in
                    if appliedSelection.restoreSampleEncounter,
                       let encounter = SampleEncounter.restore(
                        database: database,
                        crashReporter: crashReporter,
                        ruleset: WelcomeFeature.sampleEncounterRuleset(selection: appliedSelection.selection)
                       ) {
                        await send(.navigation(.openEncounter(encounter)))
                    }
                    await send(.destination(.dismiss))
                }
            case .destination:
                break
            case .presentCrashReportingPermissionAlert:
                state.crashReportingPermissionAlert = AlertState {
                    TextState("Construct quit unexpectedly.")
                } actions: {
                    ButtonState(role: .cancel, action: .send(.dontSend)) {
                        TextState("Don't send")
                    }
                    ButtonState(action: .send(.send)) {
                        TextState("Send")
                    }
                } message: {
                    TextState("Do you want to send an anonymous crash reports so I can fix the issue?")
                }
            case .alert(let presentationAction):
                switch presentationAction {
                case .presented(.send):
                    return .send(.onReceiveCrashReportingUserPermission(.send))
                case .presented(.dontSend):
                    return .send(.onReceiveCrashReportingUserPermission(.dontSend))
                case .dismiss:
                    state.crashReportingPermissionAlert = nil
                }
            case .onReceiveCrashReportingUserPermission(let permission):
                crashReporter.registerUserPermission(permission)
                if state.preferences.errorReportingEnabled != (permission == .send) {
                    state.$preferences.withLock { $0.errorReportingEnabled = permission == .send }
                }
            case .onAppear:
                let environment = ProcessInfo.processInfo.environment
                let isUiTesting = environment["CONSTRUCT_UI_TESTS"] == "1"
                let shouldForceWelcomeForUITests = isUiTesting && environment["CONSTRUCT_UI_TESTS_FORCE_WELCOME"] != "0"
                if shouldForceWelcomeForUITests || !state.preferences.didShowWelcomeSheet {
                    return .send(.requestDestination(.welcome(.init())))
                } else if state.preferences.dismissedDefaultContentUpdatePromptToken != defaultContentUpdateDismissalToken() {
                    return .send(.requestDestination(.defaultContentSelection(.init(
                        preselectImportedRulesets: true
                    ))))
                } else if let nodeCount = try? campaignBrowser.nodeCount(),
                          nodeCount >= CampaignBrowser.initialSpecialNodeCount+2
                {
                    #if !DEBUG
                    return .run { _ in
                        await appReview.requestAppStoreReview()
                    }
                    #endif
                }
            case .scene(let phase):
                state.sceneIsActive = phase == .active
            case .onOpenURL(let url):
                guard let invocation = try? appInvocationRouter.match(url: url) else { break }
                if case .diceRoller(let roller) = invocation {
                    state.navigation?.tabState?.selectedTab = .diceRoller
                    state.navigation?.tabState?.diceRoller.calculatorState.mode = .editingExpression
                    state.navigation?.tabState?.diceRoller.calculatorState.reset()
                    state.navigation?.tabState?.diceRoller.calculatorState.expression = roller.expression

                    state.navigation?.columnState?.diceCalculator.hidden = false
                    state.navigation?.columnState?.diceCalculator.diceCalculator.mode = .editingExpression
                    state.navigation?.columnState?.diceCalculator.diceCalculator.reset()
                    state.navigation?.columnState?.diceCalculator.diceCalculator.expression = roller.expression
                }
            case .onProcessRollForDiceLog(let result, let roll):
                if state.navigation?.tabState != nil {
                    return .send(.navigation(.tab(.diceRoller(.onProcessRollForDiceLog(result, roll)))))
                } else {
                    return .send(.navigation(.column(.diceCalculator(.onProcessRollForDiceLog(result, roll)))))
                }
            }
            return .none
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.navigation, action: \.navigation) {
            Navigation()
        }
        Reduce { state, action in
            let idleTimerDisabled = state.sceneIsActive
                && state.firstNavigationNode(of: EncounterDetailFeature.State.self)?.running != nil
            return .run { _ in
                await idleTimer.setIdleTimerDisabled(idleTimerDisabled)
            }
        }
    }

    private func defaultContentUpdateDismissalToken() -> String {
        return DefaultContentSource.allCases
            .map { source in "\(source.importSourceId.rawValue):\(source.currentVersion)" }
            .joined(separator: "|")
    }

    @Reducer
    struct Navigation {

        @ObservableState
        @CasePathable
        enum State: Equatable {
            case tab(TabNavigationFeature.State)
            case column(ColumnNavigationFeature.State)

            var tabState: TabNavigationFeature.State? {
                get {
                    guard case .tab(let s) = self else { return nil }
                    return s
                }
                set {
                    if let newValue = newValue {
                        self = .tab(newValue)
                    }
                }
            }

            var columnState: ColumnNavigationFeature.State? {
                get {
                    guard case .column(let s) = self else { return nil }
                    return s
                }
                set {
                    if let newValue = newValue {
                        self = .column(newValue)
                    }
                }
            }
        }

        @CasePathable
        enum Action: Equatable {
            case openEncounter(Encounter)

            case tab(TabNavigationFeature.Action)
            case column(ColumnNavigationFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Reduce<State, Action> { state, action in
                switch (state, action) {
                case (.tab, .openEncounter(let e)):
                    return .send(.tab(.openEncounter(e)))
                case (.column, .openEncounter(let e)):
                    return .send(.column(.openEncounter(e)))
                default:
                    break
                }
                return .none
            }
            .ifCaseLet(\.tab, action: \.tab) {
                TabNavigationFeature()
            }
            .ifCaseLet(\.column, action: \.column) {
                ColumnNavigationFeature()
            }
        }
    }

}

enum AppNavigation: Equatable {
    case tab
    case column
}

struct AppNavigationEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppNavigation = .tab
}

extension EnvironmentValues {
    var appNavigation: AppNavigation {
        get { self[AppNavigationEnvironmentKey.self] }
        set { self[AppNavigationEnvironmentKey.self] = newValue }
    }
}

extension AppFeature.State {
    var localStateForDeduplication: AppFeature.State {
        var res = self
        switch res.navigation {
        case .column:
            res.navigation = .column(ColumnNavigationFeature.State.nullInstance)
        case .tab:
            res.navigation = .tab(TabNavigationFeature.State.nullInstance)
        case nil:
            res.navigation = nil
        }
        return res
    }
}

extension TabNavigationFeature.State {
    var columnNavigationViewState: ColumnNavigationFeature.State {
        let def = ColumnNavigationFeature.State()
        return ColumnNavigationFeature.State(
            campaignBrowse: campaignBrowserForColumnNavigation,
            simpleAdventure: simpleAdventure,
            referenceView: ReferenceViewFeature.State(
                items: [
                    ReferenceViewFeature.Item.State(
                        state: ReferenceItem.State(
                            content: .compendium(
                                ReferenceItem.State.Content.Compendium(
                                    compendium: compendium
                                )
                            )
                        )
                    )
                ]
            ),
            diceCalculator: FloatingDiceRollerFeature.State(
                hidden: false,
                diceCalculator: apply(def.diceCalculator.diceCalculator) {
                    $0.expression = diceRoller.calculatorState.expression
                    $0.result = diceRoller.calculatorState.result
                    $0.previousExpressions = diceRoller.calculatorState.previousExpressions
                    $0.entryContext = diceRoller.calculatorState.entryContext
                }
            )
        )
    }
}

extension ColumnNavigationFeature.State {
    var tabNavigationViewState: TabNavigationFeature.State {
        let def = TabNavigationFeature.State()
        let activeCompendiumReferenceItemTab = referenceView.items
            .first(where: { $0.id == referenceView.selectedItemId })
            .flatMap {
                $0.state.content[case: \.compendium]?.compendium
            }

        let selectedTab: TabNavigationFeature.State.Tabs = {
            if diceCalculator.diceCalculator.mode == .editingExpression {
                return .diceRoller
            }

            if !navigationNodes(of: EncounterDetailFeature.State.self).isEmpty {
                return .campaign
            }

            if activeCompendiumReferenceItemTab != nil {
                return .compendium
            }

            return def.selectedTab
        }()

        return TabNavigationFeature.State(
            selectedTab: selectedTab,
            campaignBrowser: campaignBrowse,
            simpleAdventure: simpleAdventureForTabNavigation,
            compendium: activeCompendiumReferenceItemTab ?? def.compendium,
            diceRoller: apply(def.diceRoller) {
                $0.calculatorState.expression = diceCalculator.diceCalculator.expression
                $0.calculatorState.result = diceCalculator.diceCalculator.result
                $0.calculatorState.previousExpressions = diceCalculator.diceCalculator.previousExpressions
                $0.calculatorState.entryContext = diceCalculator.diceCalculator.entryContext
            }
        )
    }
}

extension AppFeature.Destination.State: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.welcome(lhsState), .welcome(rhsState)):
            return lhsState == rhsState
        case let (.defaultContentSelection(lhsState), .defaultContentSelection(rhsState)):
            return lhsState == rhsState
        default:
            return false
        }
    }
}

extension AppFeature.Destination.Action: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.welcome(lhsAction), .welcome(rhsAction)):
            return lhsAction == rhsAction
        case let (.defaultContentSelection(lhsAction), .defaultContentSelection(rhsAction)):
            return lhsAction == rhsAction
        default:
            return false
        }
    }
}

extension AppFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        let nodes: [Any] = [self]
        if case .some(.welcome) = destination {
            return nodes
        }
        guard let navigation else { return nodes }
        return nodes + navigation.navigationNodes
    }
}

extension AppFeature.Navigation.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .tab(let state): return [self] + state.navigationNodes
        case .column(let state): return [self] + state.navigationNodes
        }
    }
}
