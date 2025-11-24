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

@Reducer
struct AppFeature: Reducer {

    @ObservableState
    struct State: Equatable {

        var navigation: Navigation.State?
        var presentation: Presentation?
        var pendingPresentations: [Presentation] = []

        var sceneIsActive = false
        
        @Presents var crashReportingPermissionAlert: AlertState<Action.Alert>?

        enum Presentation: Equatable {
            case welcomeSheet
            case crashReportingPermissionAlert
        }
    }

    enum Action: Equatable {
        case onLaunch
        case navigation(Navigation.Action)

        case onHorizontalSizeClassChange(UserInterfaceSizeClass)

        case requestPresentation(State.Presentation)
        case dismissPresentation(State.Presentation)

        case onReceiveCrashReportingUserPermission(CrashReporter.UserPermission)

        case welcomeSheetSampleEncounterTapped
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

    @Dependency(\.appReview) var appReview
    @Dependency(\.campaignBrowser) var campaignBrowser
    @Dependency(\.crashReporter) var crashReporter
    @Dependency(\.database) var database
    @Dependency(\.diceLog) var diceLog
    @Dependency(\.idleTimer) var idleTimer
    @Dependency(\.preferences) var preferencesClient
    @Dependency(\.storeManager) var storeManager

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onLaunch:
                return .merge(
                    .run { send in
                        // Check Crashlytics
                        if Crashlytics.crashlytics().didCrashDuringPreviousExecution() {
                            if preferencesClient.get().errorReportingEnabled == true {
                                // user consent has been given, send reports
                                crashReporter.registerUserPermission(.send)
                            }

                            await send(.requestPresentation(.crashReportingPermissionAlert))
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
            case .requestPresentation(let p):
                precondition(p != .welcomeSheet || !database.needsPrepareForUse)

                if state.presentation == nil {
                    state.presentation = p
                    if p == .crashReportingPermissionAlert {
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
                    }
                } else {
                    state.pendingPresentations.append(p)
                }
            case .dismissPresentation(let p):
                // we can't add this precondition because SwiftUI invokes the isPresented binding
                // _after_ we hid the sheet by nilling underlying field.
                // Instead, we ignore the dismiss action
                // precondition(state.presentation == p)
                guard state.presentation == p else { break }
                state.presentation = nil
                if p == .crashReportingPermissionAlert {
                    state.crashReportingPermissionAlert = nil
                }

                if let next = state.pendingPresentations.first {
                    state.pendingPresentations.removeFirst()
                    // workaround: we need to delay the action to work around
                    // a "Attempt to present X which is already presenting Y" error
                    return .run { send in
                        try await Task.sleep(for: .seconds(0.1))
                        await send(.requestPresentation(next))
                    }
                }
            case .alert(let presentationAction):
                switch presentationAction {
                case .presented(.send):
                    return .send(.onReceiveCrashReportingUserPermission(.send))
                case .presented(.dontSend):
                    return .send(.onReceiveCrashReportingUserPermission(.dontSend))
                case .dismiss:
                    return .send(.dismissPresentation(.crashReportingPermissionAlert))
                }
            case .onReceiveCrashReportingUserPermission(let permission):
                crashReporter.registerUserPermission(permission)
                var preferences = preferencesClient.get()
                if preferences.errorReportingEnabled != (permission == .send) {
                    preferences.errorReportingEnabled = permission == .send
                    try? preferencesClient.update { $0.errorReportingEnabled = permission == .send }
                }
            case .welcomeSheetSampleEncounterTapped:
                return .run { send in
                    SampleEncounter.create(database: database, crashReporter: crashReporter)

                    if let encounter: Encounter = try? database.keyValueStore.get(
                        Encounter.key(Encounter.scratchPadEncounterId),
                        crashReporter: crashReporter
                    ) {
                        await send(.navigation(.openEncounter(encounter)))
                    }

                    await send(.dismissPresentation(.welcomeSheet))
                }
            case .onAppear:
                if !preferencesClient.get().didShowWelcomeSheet {
                    return .send(.requestPresentation(.welcomeSheet))
                } else if let nodeCount = try? campaignBrowser.nodeCount(),
                          nodeCount >= CampaignBrowser.initialSpecialNodeCount+2
                {
                    // if the user created some campaign nodes
                    #if !DEBUG
                    appReview.requestAppStoreReview()
                    #endif
                }
            case .scene(let phase):
                state.sceneIsActive = phase == .active
            case .onOpenURL(let url):
                guard let invocation = try? appInvocationRouter.match(url: url) else { break }
                if case .diceRoller(let roller) = invocation {
                    // tab
                    state.navigation?.tabState?.selectedTab = .diceRoller
                    state.navigation?.tabState?.diceRoller.calculatorState.mode = .editingExpression
                    state.navigation?.tabState?.diceRoller.calculatorState.reset()
                    state.navigation?.tabState?.diceRoller.calculatorState.expression = roller.expression

                    // column
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
        .onChange(of: \.presentation) { oldValue, newValue in
            Reduce { state, action in
                if newValue == .welcomeSheet {
                    try? preferencesClient.update {
                        $0.didShowWelcomeSheet = true
                    }
                }
                return .none
            }
        }
        .ifLet(\.navigation, action: \.navigation) {
            Navigation()
        }
        Reduce { state, action in
            if state.sceneIsActive, let edv = state.firstNavigationNode(of: EncounterDetailFeature.State.self), edv.running != nil {
                idleTimer.isIdleTimerDisabled.wrappedValue = true
            } else {
                idleTimer.isIdleTimerDisabled.wrappedValue = false
            }
            return .none
        }
    }

    @Reducer
    struct Navigation: Reducer {

        @ObservableState
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

        enum Action: Equatable {
            case openEncounter(Encounter)

            case tab(TabNavigationFeature.Action)
            case column(ColumnNavigationFeature.Action)
        }

        @Dependency(\.preferences) var preferencesClient

        var body: some ReducerOf<Self> {
            Reduce<State, Action> { state, action in
                switch (state, action) {
                case (.tab, .openEncounter(let e)):
                    let detailState = EncounterDetailFeature.State(
                        building: e,
                        isMechMuseEnabled: preferencesClient.get().mechMuse.enabled
                    )
                    return .send(.tab(.campaignBrowser(.setDestination(.encounter(detailState)))))
                case (.column, .openEncounter(let e)):
                    let detailState = EncounterDetailFeature.State(
                        building: e,
                        isMechMuseEnabled: preferencesClient.get().mechMuse.enabled
                    )
                    return .send(.column(.campaignBrowse(.setDestination(.encounter(detailState)))))
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
            campaignBrowse: campaignBrowser,
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
                $0.state.content.compendiumState?.compendium
            }

        let selectedTab: TabNavigationFeature.State.Tabs = {
            if diceCalculator.diceCalculator.mode == .editingExpression {
                return .diceRoller
            }

            if !campaignBrowse.navigationNodes(of: EncounterDetailFeature.State.self).isEmpty {
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

extension AppFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        let nodes: [Any] = [self]
        guard presentation != .welcomeSheet else { return nodes }
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
