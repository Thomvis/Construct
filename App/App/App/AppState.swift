//
//  AppState.swift
//  Construct
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture
import DiceRollerFeature
import Helpers
import URLRouting

struct AppState: Equatable {

    var navigation: Navigation?
    var presentation: Presentation?
    var pendingPresentations: [Presentation] = []

    var preferences: Preferences

    var showPostLaunchLoadingScreen = false

    var appDidLaunch = false // becomes true once the scene has become active for the first time
    var sceneIsActive = false

    var topNavigationItems: [Any] {
        guard presentation != .welcomeSheet else { return [] }
        switch navigation {
        case .tab(let s): return s.topNavigationItems
        case .column(let s): return s.topNavigationItems
        case nil: return []
        }
    }

    enum Navigation: Equatable {
        case tab(TabNavigationViewState)
        case column(ColumnNavigationViewState)

        var tabState: TabNavigationViewState? {
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

        var columnState: ColumnNavigationViewState? {
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

    enum Presentation: Equatable {
        case welcomeSheet
        case crashReportingPermissionAlert
    }

    enum Action: Equatable {
        case onLaunch
        case navigation(AppStateNavigationAction)

        case onHorizontalSizeClassChange(UserInterfaceSizeClass)

        case requestPresentation(AppState.Presentation)
        case dismissPresentation(AppState.Presentation)

        case onReceiveCrashReportingUserPermission(CrashReporter.UserPermission)

        case welcomeSheetSampleEncounterTapped
        case onAppear

        case showPostLaunchLoadingScreen(Bool)
        case parseableManagerDidFinish

        case sceneDidBecomeActive
        case sceneWillResignActive

        case onOpenURL(URL)

        case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
    }

    static var reducer: Reducer<AppState, Action, Environment> {
        return Reducer.combine(
            Reducer { state, action, env in
                switch action {
                case .onLaunch:
                    // Listen to dice rolls and forward them to the right place
                    return env.diceLog.rolls.map { (result, roll) in
                        .onProcessRollForDiceLog(result, roll)
                    }
                    .eraseToEffect()
                    .cancellable(id: "diceLog", cancelInFlight: true)
                case .navigation: break // handled below
                case .onHorizontalSizeClassChange(let sizeClass):
                    switch (state.navigation, sizeClass) {
                    case (nil, .compact):
                        state.navigation = .tab(TabNavigationViewState())
                    case (.column(let prev), .compact):
                        state.navigation = .tab(prev.tabNavigationViewState)
                    case (nil, .regular):
                        state.navigation = .column(ColumnNavigationViewState())
                    case (.tab(let prev), .regular):
                        state.navigation = .column(prev.columnNavigationViewState)
                    default:
                        break
                    }
                case .requestPresentation(let p):
                    if state.presentation == nil {
                        state.presentation = p
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

                    if let next = state.pendingPresentations.first {
                        state.pendingPresentations.removeFirst()
                        // workaround: we need to delay the action to work around
                        // a "Attempt to present X which is already presenting Y" error
                        return .init(value: .requestPresentation(next))
                            .delay(for: 0.1, scheduler: env.mainQueue)
                            .eraseToEffect()
                    }
                case .onReceiveCrashReportingUserPermission(let permission):
                    env.crashReporter.registerUserPermission(permission)
                case .welcomeSheetSampleEncounterTapped:
                    return SampleEncounter.create(with: env)
                        .append(Effect.result { () -> Result<Action?, Never> in
                            // navigate to scratch pad
                            if let encounter: Encounter = try? env.database.keyValueStore.get(
                                Encounter.key(Encounter.scratchPadEncounterId),
                                crashReporter: env.crashReporter
                            ) {
                                return .success(.navigation(.openEncounter(encounter)))
                            } else {
                                return .success(nil)
                            }
                        }.compactMap { $0 }.append(.dismissPresentation(.welcomeSheet))).eraseToEffect()
                case .onAppear:
                    if !state.preferences.didShowWelcomeSheet {
                        return .init(value: .requestPresentation(.welcomeSheet))
                    } else {
                        // check if user created some campaign nodes
                        if let nodeCount = try? env.campaignBrowser.nodeCount(),
                           nodeCount >= CampaignBrowser.initialSpecialNodeCount+2
                        {
                            env.requestAppStoreReview()
                        }
                    }
                case .showPostLaunchLoadingScreen(let b):
                    state.showPostLaunchLoadingScreen = b
                case .parseableManagerDidFinish:
                    state.preferences.parseableManagerLastRunVersion = DomainParsers.combinedVersion
                case .sceneDidBecomeActive:
                    state.sceneIsActive = true

                    if (!state.appDidLaunch) {
                        defer {
                            state.appDidLaunch = true
                        }

                        if state.preferences.parseableManagerLastRunVersion != DomainParsers.combinedVersion {
                            return Effect<Void, Never>.future { callback in
                                DispatchQueue.global().async {
                                    try? env.database.parseableManager.run()
                                    callback(.success(()))
                                }
                            }
                            .receive(on: DispatchQueue.main)
                            .ensureMinimumIntervalUntilFirstOutput(2.0, scheduler: DispatchQueue.main)
                            .flatMap { _ in [.parseableManagerDidFinish, .showPostLaunchLoadingScreen(false)].publisher }
                            .receive(on: DispatchQueue.main.animation(.default)) // animate the disappearance, not the appearance
                            .prepend(.showPostLaunchLoadingScreen(true))
                            .eraseToEffect()
                        }
                    }
                case .sceneWillResignActive:
                    state.sceneIsActive = false
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
                        return Effect(value: .navigation(.tab(.diceRoller(.onProcessRollForDiceLog(result, roll)))))
                    } else {
                        return Effect(value: .navigation(.column(.diceCalculator(.onProcessRollForDiceLog(result, roll)))))
                    }
                }
                return .none
            }.onChange(of: { $0.presentation}) { p, state, a, env in
                if p == .welcomeSheet {
                    state.preferences.didShowWelcomeSheet = true
                }
                return .none
            },
            Navigation.reducer.optional().pullback(state: \.navigation, action: /AppState.Action.navigation),
            Reducer { state, action, env in
                if state.sceneIsActive, let edv = state.topNavigationItems.compactMap({ $0 as? EncounterDetailViewState }).first, edv.running != nil {
                    env.isIdleTimerDisabled.wrappedValue = true
                } else {
                    env.isIdleTimerDisabled.wrappedValue = false
                }
                return .none
            }
        )
    }
}

enum AppStateNavigationAction: Equatable {
    case openEncounter(Encounter)

    case tab(TabNavigationViewAction)
    case column(ColumnNavigationViewAction)
}

extension AppState.Navigation {
    static let reducer: Reducer<Self, AppStateNavigationAction, Environment> = Reducer.combine(
        Reducer { state, action, env in
            switch (state, action) {
            case (.tab, .openEncounter(let e)):
                return Effect(value: .tab(.campaignBrowser(.setNextScreen(.encounter(EncounterDetailViewState(building: e))))))
            case (.column, .openEncounter(let e)):
                return Effect(value: AppStateNavigationAction.column(.campaignBrowse(.setNextScreen(.encounter(EncounterDetailViewState(building: e))))))
            default:
                break
            }
            return .none
        },
        TabNavigationViewState.reducer.optional().pullback(state: \.tabState, action: /AppStateNavigationAction.tab),
        ColumnNavigationViewState.reducer.optional().pullback(state: \.columnState, action: /AppStateNavigationAction.column)
    )
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

extension AppState {
    var localStateForDeduplication: AppState {
        var res = self
        switch res.navigation {
        case .column:
            res.navigation = .column(ColumnNavigationViewState.nullInstance)
        case .tab:
            res.navigation = .tab(TabNavigationViewState.nullInstance)
        case nil:
            res.navigation = nil
        }
        return res
    }
}

extension TabNavigationViewState {
    var columnNavigationViewState: ColumnNavigationViewState {
        let def = ColumnNavigationViewState()
        return ColumnNavigationViewState(
            campaignBrowse: campaignBrowser,
            referenceView: ReferenceViewState(
                items: [
                    ReferenceViewState.Item(
                        state: ReferenceItemViewState(
                            content: .home(
                                ReferenceItemViewState.Content.Home(
                                    presentedScreens: compendium.presentedNextCompendiumIndex.map { [.nextInStack: .compendium($0)] } ?? [:]
                                )
                            )
                        )
                    )
                ]
            ),
            diceCalculator: FloatingDiceRollerViewState(
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

extension ColumnNavigationViewState {
    var tabNavigationViewState: TabNavigationViewState {
        let def = TabNavigationViewState()

        let activeCompendiumReferenceItemTab = referenceView.items
            .first(where: { $0.id == referenceView.selectedItemId })
            .flatMap {
                $0.state.content.homeState?.presentedNextCompendium
            }

        let selectedTab: TabNavigationViewState.Tabs = {
            if diceCalculator.diceCalculator.mode == .editingExpression {
                return .diceRoller
            }

            if campaignBrowse.topNavigationItems().contains(where: { $0 is EncounterDetailViewState }) {
                return .campaign
            }

            if activeCompendiumReferenceItemTab != nil {
                return .compendium
            }

            return def.selectedTab
        }()

        return TabNavigationViewState(
            selectedTab: selectedTab,
            campaignBrowser: campaignBrowse,
            compendium: apply(def.compendium) {
                if activeCompendiumReferenceItemTab != nil {
                    $0.presentedNextCompendiumIndex = activeCompendiumReferenceItemTab
                }
            },
            diceRoller: apply(def.diceRoller) {
                $0.calculatorState.expression = diceCalculator.diceCalculator.expression
                $0.calculatorState.result = diceCalculator.diceCalculator.result
                $0.calculatorState.previousExpressions = diceCalculator.diceCalculator.previousExpressions
                $0.calculatorState.entryContext = diceCalculator.diceCalculator.entryContext
            }
        )
    }
}
